from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from ..db import get_db
from ..dependencies import current_user
from ..models import (
    AnalyticsEvent,
    Application,
    ApplicationStatusHistory,
    AuditLog,
    AuthSession,
    FarmerCrop,
    FarmerDocument,
    FarmerLand,
    FarmerProfile,
    Feedback,
    Notification,
    Pilot,
    PilotSurvey,
    RecommendationSnapshot,
    SavedScheme,
    Scheme,
    SchemeVersion,
    User,
)
from ..schemas import AccountDeleteRequest
from ..security import clear_session_cookies, verify_password

router = APIRouter(prefix="/api/v1", tags=["account and privacy"])


@router.delete("/account")
def delete_account(
    payload: AccountDeleteRequest,
    response: Response,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    """Delete the authenticated account and user-linked profile/product data.

    A password re-check and explicit DELETE confirmation are required. Non-user
    scheme history is retained, but verification/audit actor identifiers are
    detached or redacted where they would otherwise point at the deleted user.
    """
    if user.is_demo:
        raise HTTPException(status_code=403, detail="The synthetic demo account cannot be deleted.")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="The password is incorrect. No account data was deleted.")

    if user.role == "SUPER_ADMIN":
        active_admins = db.scalar(
            select(func.count(User.id)).where(User.role == "SUPER_ADMIN", User.is_active.is_(True))
        ) or 0
        if active_admins <= 1:
            raise HTTPException(status_code=409, detail="Transfer super-admin responsibility before deleting the last active super-admin account.")

    user_id = user.id
    application_ids = select(Application.id).where(Application.user_id == user_id)
    db.execute(delete(ApplicationStatusHistory).where(ApplicationStatusHistory.application_id.in_(application_ids)))
    db.execute(delete(Application).where(Application.user_id == user_id))
    db.execute(delete(SavedScheme).where(SavedScheme.user_id == user_id))
    db.execute(delete(Notification).where(Notification.user_id == user_id))
    db.execute(delete(RecommendationSnapshot).where(RecommendationSnapshot.user_id == user_id))
    db.execute(delete(Feedback).where(Feedback.user_id == user_id))
    db.execute(delete(AnalyticsEvent).where(AnalyticsEvent.user_id == user_id))
    db.execute(delete(PilotSurvey).where(PilotSurvey.user_id == user_id))
    db.execute(delete(FarmerDocument).where(FarmerDocument.user_id == user_id))
    db.execute(delete(FarmerCrop).where(FarmerCrop.user_id == user_id))
    db.execute(delete(FarmerLand).where(FarmerLand.user_id == user_id))
    db.execute(delete(FarmerProfile).where(FarmerProfile.user_id == user_id))
    db.execute(delete(AuthSession).where(AuthSession.user_id == user_id))

    # Retain scheme records, but remove the deleted user's identity as a verifier.
    db.execute(update(Scheme).where(Scheme.verified_by == user_id).values(verified_by=None))
    db.execute(update(SchemeVersion).where(SchemeVersion.verified_by == user_id).values(verified_by=None))
    db.execute(update(Pilot).where(Pilot.created_by == user_id).values(created_by=None))

    # Preserve unrelated governance history without retaining the deleted user ID.
    db.execute(delete(AuditLog).where(AuditLog.entity_type == "user", AuditLog.entity_id == user_id))
    db.execute(update(AuditLog).where(AuditLog.actor_user_id == user_id).values(actor_user_id=None))
    db.delete(user)
    db.add(AuditLog(
        actor_user_id=None,
        action="ACCOUNT_DELETED",
        entity_type="account",
        entity_id="user-requested-deletion",
        old_value=None,
        new_value={"user_data_removed": True},
        reason="Password-confirmed account deletion; direct identifiers redacted.",
    ))
    db.commit()
    clear_session_cookies(response)
    return {
        "deleted": True,
        "message": "The account and user-linked profile, saved items, tracker, checklist, survey, feedback, and session data were deleted from the live application database.",
        "backup_note": "Copies in encrypted backups, if configured, follow the deployment's published backup-retention schedule.",
    }
