from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend import db as db_module
from backend.api import main
from backend.db import Base
from backend.models import User
from backend.security import hash_password


@pytest.fixture
def client(monkeypatch):
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    testing_sessions = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    Base.metadata.create_all(bind=engine)
    monkeypatch.setattr(db_module, "engine", engine)
    monkeypatch.setattr(db_module, "SessionLocal", testing_sessions)
    monkeypatch.setattr(main, "engine", engine)
    monkeypatch.setattr(main, "SessionLocal", testing_sessions)
    with TestClient(main.app) as test_client:
        yield test_client, testing_sessions
    engine.dispose()


def csrf_headers(client: TestClient) -> dict[str, str]:
    token = client.cookies.get("scheme_mitra_csrf")
    assert token
    return {"X-CSRF-Token": token}


def test_cookie_session_csrf_and_server_side_logout_revocation(client):
    http, _ = client
    response = http.post("/api/v1/auth/demo", json={})
    assert response.status_code == 200
    access_token = http.cookies.get("scheme_mitra_access")
    assert access_token
    assert http.get("/api/v1/profile").status_code == 200
    assert http.get("/api/v1/saved").status_code == 200
    generated = http.post("/api/v1/recommendations/generate", json={}, headers=csrf_headers(http))
    assert generated.status_code == 200
    # Seed records remain under review and must not leak into farmer/demo routes.
    assert generated.json()["recommendations"] == []

    # Authenticated unsafe requests fail closed without the double-submit token.
    assert http.patch("/api/v1/documents/land_7_12", json={"state": "available"}).status_code == 403
    update = http.patch("/api/v1/documents/land_7_12", json={"state": "available"}, headers=csrf_headers(http))
    assert update.status_code == 200
    assert update.json()["validated"] is False

    assert http.post("/api/v1/auth/logout", json={}, headers=csrf_headers(http)).status_code == 200
    # A copied signed token cannot be reused after the server-side session is revoked.
    http.cookies.set("scheme_mitra_access", access_token)
    assert http.get("/api/v1/profile").status_code == 401


def test_farmer_role_cannot_access_admin_and_super_admin_can_publish(client):
    http, session_factory = client
    farmer = http.post("/api/v1/auth/register", json={
        "email": "farmer@example.com", "password": "FarmPassword2026!", "full_name": "Test Farmer",
        "state": "Maharashtra", "district": "Nashik", "taluka": "Niphad",
    })
    assert farmer.status_code == 201
    assert http.get("/api/v1/admin/overview").status_code == 403
    assert http.post("/api/v1/auth/logout", json={}, headers=csrf_headers(http)).status_code == 200

    with session_factory() as db:
        db.add(User(email="admin@example.com", full_name="Test Admin", password_hash=hash_password("AdminPassword2026!"), role="SUPER_ADMIN", is_active=True))
        db.add(User(email="verifier@example.com", full_name="Test Verifier", password_hash=hash_password("VerifierPassword2026!"), role="DATA_VERIFIER", is_active=True))
        db.commit()

    login = http.post("/api/v1/auth/login", json={"email": "admin@example.com", "password": "AdminPassword2026!"})
    assert login.status_code == 200
    headers = csrf_headers(http)
    assert http.get("/api/v1/admin/overview").status_code == 200

    scheme = {
        "slug": "test-admin-scheme", "name": "Test Admin Scheme", "department": "Agriculture Department, Government of Maharashtra",
        "level": "State", "category": "Irrigation", "source_name": "MahaDBT Farmer Portal",
        "source_url": "https://mahadbt.maharashtra.gov.in/Farmer/SchemeData/SchemeData?str=E9DDFA703C38E51AC7B56240D6D84F28",
        "application_url": "https://mahadbt.maharashtra.gov.in/Farmer/Login/Login",
        "summary": "A source-backed test record for workflow coverage.", "benefit_summary": "Not specified in this test record.",
        "application_process": ["Open the official application route and confirm current steps."],
        "need": "irrigation", "crop_tags": ["onion"], "source_facts": ["A test source fact from the official source page."],
        "source_review_complete": True, "ruleset_complete": False, "eligibility_rules": [],
        "document_items": [{"id": "land_record", "label": "Land record", "stage": "Before applying", "required": True}],
        "document_review_note": "The official source lists the land record before applying; confirm current component requirements.",
        "documents_review_complete": True,
        "checks": [{"id": "aadhaar", "label": "Aadhaar availability", "field": "aadhaar_present", "kind": "boolean"}],
        "name_mr": "", "icon": "water", "source_checked_at": "2026-10-07",
    }
    unreviewed_documents = {**scheme, "slug": "missing-document-review", "documents_review_complete": False, "document_review_note": ""}
    unreviewed_create = http.post("/api/v1/admin/schemes", json=unreviewed_documents, headers=headers)
    assert unreviewed_create.status_code == 201
    assert http.post("/api/v1/admin/schemes/missing-document-review/verify", json={"reason": "Editor cannot verify own version"}, headers=headers).status_code == 409

    created = http.post("/api/v1/admin/schemes", json=scheme, headers=headers)
    assert created.status_code == 201
    assert created.json()["scheme"]["status"] == "UNDER_REVIEW"
    assert http.get("/api/v1/schemes").json()["count"] == 0
    self_verified = http.post("/api/v1/admin/schemes/test-admin-scheme/verify", json={"reason": "Editor cannot verify own version"}, headers=headers)
    assert self_verified.status_code == 409
    self_publish = http.post("/api/v1/admin/schemes/test-admin-scheme/publish", json={"reason": "Unverified version"}, headers=headers)
    assert self_publish.status_code == 409

    assert http.post("/api/v1/auth/logout", json={}, headers=headers).status_code == 200
    verifier_login = http.post("/api/v1/auth/login", json={"email": "verifier@example.com", "password": "VerifierPassword2026!"})
    assert verifier_login.status_code == 200
    verifier_headers = csrf_headers(http)
    missing_document_review = http.post("/api/v1/admin/schemes/missing-document-review/verify", json={"reason": "Documents not reviewed"}, headers=verifier_headers)
    assert missing_document_review.status_code == 422
    verified = http.post("/api/v1/admin/schemes/test-admin-scheme/verify", json={"reason": "Independent verifier review"}, headers=verifier_headers)
    assert verified.status_code == 200
    assert verified.json()["scheme"]["verification_status"] == "VERIFIED"
    assert http.get("/api/v1/schemes").json()["count"] == 0
    # Verifier-role accounts cannot publish; publication is a separate admin action.
    assert http.post("/api/v1/admin/schemes/test-admin-scheme/publish", json={"reason": "Verifier cannot publish"}, headers=verifier_headers).status_code == 403

    assert http.post("/api/v1/auth/logout", json={}, headers=verifier_headers).status_code == 200
    publisher_login = http.post("/api/v1/auth/login", json={"email": "admin@example.com", "password": "AdminPassword2026!"})
    assert publisher_login.status_code == 200
    publisher_headers = csrf_headers(http)
    published = http.post("/api/v1/admin/schemes/test-admin-scheme/publish", json={"reason": "Independent verifier sign-off"}, headers=publisher_headers)
    assert published.status_code == 200
    assert published.json()["scheme"]["status"] == "PUBLISHED"
    visible = http.get("/api/v1/schemes").json()["schemes"]
    assert [item["slug"] for item in visible] == ["test-admin-scheme"]
    assert visible[0]["evaluation"]["status"] == "INSUFFICIENT_INFORMATION"


def test_health_and_admin_static_page_are_served(client):
    http, _ = client
    assert http.get("/health").status_code == 200
    assert http.get("/ready").status_code == 200
    page = http.get("/admin.html")
    assert page.status_code == 200
    assert "Scheme administration" in page.text
