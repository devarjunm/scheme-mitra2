from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend import db as db_module
from backend.api import main
from backend.db import Base
from backend.models import AuthSession, FarmerProfile, User


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


def _mobile_register(http: TestClient, email: str):
    result = http.post("/api/v1/auth/mobile/register", json={
        "email": email,
        "password": "FarmerPassword2026!",
        "full_name": "Mobile Farmer",
        "state": "Maharashtra",
        "district": "Nashik",
        "taluka": "Niphad",
    })
    assert result.status_code == 201, result.text
    body = result.json()
    assert body["token_type"] == "Bearer"
    assert body["access_token"]
    return body


def test_mobile_bearer_authentication_and_logout_revocation(client):
    http, _ = client
    registered = _mobile_register(http, "mobile-farmer@example.com")
    headers = {"Authorization": f"Bearer {registered['access_token']}"}

    me = http.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["authenticated"] is True
    assert me.json()["user"]["email"] == "mobile-farmer@example.com"
    assert http.get("/api/v1/profile", headers=headers).status_code == 200
    assert http.get("/api/v1/schemes", headers=headers).json()["count"] == 0

    logout = http.post("/api/v1/auth/mobile/logout", json={}, headers=headers)
    assert logout.status_code == 200
    assert http.get("/api/v1/profile", headers=headers).status_code == 401


def test_password_confirmed_mobile_account_deletion_removes_data_and_revokes_session(client):
    http, sessions = client
    registered = _mobile_register(http, "delete-me@example.com")
    headers = {"Authorization": f"Bearer {registered['access_token']}"}
    with sessions() as db:
        user = db.scalar(select(User).where(User.email == "delete-me@example.com"))
        assert user is not None
        user_id = user.id
        assert db.scalar(select(FarmerProfile).where(FarmerProfile.user_id == user_id)) is not None
        assert db.scalar(select(AuthSession).where(AuthSession.user_id == user_id)) is not None

    response = http.request(
        "DELETE",
        "/api/v1/account",
        json={"password": "FarmerPassword2026!", "confirmation": "DELETE"},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    assert response.json()["deleted"] is True
    assert http.get("/api/v1/profile", headers=headers).status_code == 401
    with sessions() as db:
        assert db.scalar(select(User).where(User.id == user_id)) is None
        assert db.scalar(select(FarmerProfile).where(FarmerProfile.user_id == user_id)) is None
        assert db.scalar(select(AuthSession).where(AuthSession.user_id == user_id)) is None


def test_mobile_delete_rejects_wrong_password_without_removing_account(client):
    http, sessions = client
    registered = _mobile_register(http, "keep-me@example.com")
    headers = {"Authorization": f"Bearer {registered['access_token']}"}
    response = http.request(
        "DELETE",
        "/api/v1/account",
        json={"password": "WrongPassword2026!", "confirmation": "DELETE"},
        headers=headers,
    )
    assert response.status_code == 401
    with sessions() as db:
        assert db.scalar(select(User).where(User.email == "keep-me@example.com")) is not None
