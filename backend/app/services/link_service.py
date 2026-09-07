from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.domain import CaregiverLink, LinkStatus, User
from app.schemas.links import (
    CaregiverLookupResponse,
    LinkedCaregiverResponse,
    LinkedPatientResponse,
    LinkResponse,
    PendingNotificationResponse,
)


async def lookup_caregiver_by_phone(db: AsyncSession, phone: str) -> CaregiverLookupResponse:
    user = await db.scalar(
        select(User).where(User.phone == phone, User.role == "caregiver")
    )
    if not user:
        raise HTTPException(status_code=404, detail="Caregiver dengan nomor ini tidak ditemukan")
    return CaregiverLookupResponse.model_validate(user)


async def caregiver_scan_patient(
    db: AsyncSession, caregiver: User, patient_id: str
) -> LinkResponse:
    if caregiver.role != "caregiver":
        raise HTTPException(status_code=403, detail="Hanya caregiver yang dapat scan pasien")

    patient = await db.scalar(select(User).where(User.id == patient_id, User.role == "patient"))
    if not patient:
        raise HTTPException(status_code=404, detail="Pasien tidak ditemukan")

    existing = await db.scalar(
        select(CaregiverLink).where(
            CaregiverLink.patient_id == patient_id,
            CaregiverLink.caregiver_id == caregiver.id,
        )
    )
    if existing:
        if existing.status == LinkStatus.APPROVED:
            raise HTTPException(status_code=409, detail="Pasien sudah terhubung")
        if existing.status == LinkStatus.PENDING:
            raise HTTPException(status_code=409, detail="Permintaan sudah dikirim, menunggu persetujuan pasien")
        existing.status = LinkStatus.PENDING
        existing.initiated_by = "caregiver"
        await db.commit()
        await db.refresh(existing)
        return LinkResponse.model_validate(existing)

    link = CaregiverLink(
        patient_id=patient_id,
        caregiver_id=caregiver.id,
        status=LinkStatus.PENDING,
        initiated_by="caregiver",
    )
    db.add(link)
    await db.commit()
    await db.refresh(link)
    return LinkResponse.model_validate(link)


async def patient_request_caregiver(
    db: AsyncSession,
    patient: User,
    caregiver_id: str | None,
    phone: str | None,
    relationship: str | None,
) -> LinkResponse:
    if patient.role != "patient":
        raise HTTPException(status_code=403, detail="Hanya pasien yang dapat menambah caregiver")

    if caregiver_id:
        caregiver = await db.scalar(
            select(User).where(User.id == caregiver_id, User.role == "caregiver")
        )
    elif phone:
        caregiver = await db.scalar(
            select(User).where(User.phone == phone, User.role == "caregiver")
        )
    else:
        raise HTTPException(status_code=400, detail="caregiver_id atau phone wajib diisi")

    if not caregiver:
        raise HTTPException(status_code=404, detail="Caregiver tidak ditemukan")

    existing = await db.scalar(
        select(CaregiverLink).where(
            CaregiverLink.patient_id == patient.id,
            CaregiverLink.caregiver_id == caregiver.id,
        )
    )
    if existing:
        if existing.status == LinkStatus.APPROVED:
            raise HTTPException(status_code=409, detail="Caregiver sudah terhubung")
        if existing.status == LinkStatus.PENDING:
            raise HTTPException(status_code=409, detail="Permintaan sudah dikirim, menunggu persetujuan")
        existing.status = LinkStatus.PENDING
        existing.relationship = relationship
        existing.initiated_by = "patient"
        await db.commit()
        await db.refresh(existing)
        return LinkResponse.model_validate(existing)

    link = CaregiverLink(
        patient_id=patient.id,
        caregiver_id=caregiver.id,
        status=LinkStatus.PENDING,
        relationship=relationship,
        initiated_by="patient",
    )
    db.add(link)
    await db.commit()
    await db.refresh(link)
    return LinkResponse.model_validate(link)


async def get_linked_patients(db: AsyncSession, caregiver: User) -> list[LinkedPatientResponse]:
    result = await db.execute(
        select(CaregiverLink, User)
        .join(User, User.id == CaregiverLink.patient_id)
        .where(
            CaregiverLink.caregiver_id == caregiver.id,
            CaregiverLink.status == LinkStatus.APPROVED,
        )
    )
    rows = result.all()
    return [
        LinkedPatientResponse(
            id=user.id,
            full_name=user.full_name,
            email=user.email,
            phone=user.phone,
            link_id=link.id,
            relationship=link.relationship,
        )
        for link, user in rows
    ]


async def get_linked_caregivers(db: AsyncSession, patient: User) -> list[LinkedCaregiverResponse]:
    result = await db.execute(
        select(CaregiverLink, User)
        .join(User, User.id == CaregiverLink.caregiver_id)
        .where(
            CaregiverLink.patient_id == patient.id,
            CaregiverLink.status.in_([LinkStatus.APPROVED, LinkStatus.PENDING]),
        )
    )
    rows = result.all()
    return [
        LinkedCaregiverResponse(
            id=user.id,
            full_name=user.full_name,
            email=user.email,
            phone=user.phone,
            link_id=link.id,
            status=link.status.value,
            relationship=link.relationship,
            initiated_by=link.initiated_by,
        )
        for link, user in rows
    ]


async def get_pending_notifications(
    db: AsyncSession, caregiver: User
) -> list[PendingNotificationResponse]:
    result = await db.execute(
        select(CaregiverLink, User)
        .join(User, User.id == CaregiverLink.patient_id)
        .where(
            CaregiverLink.caregiver_id == caregiver.id,
            CaregiverLink.status == LinkStatus.PENDING,
            CaregiverLink.initiated_by == "patient",
        )
        .order_by(CaregiverLink.created_at.desc())
    )
    rows = result.all()
    return [
        PendingNotificationResponse(
            link_id=link.id,
            patient_id=user.id,
            patient_name=user.full_name,
            patient_phone=user.phone,
            relationship=link.relationship,
            created_at=link.created_at,
        )
        for link, user in rows
    ]


async def approve_link(db: AsyncSession, user: User, link_id: str) -> LinkResponse:
    link = await db.scalar(select(CaregiverLink).where(CaregiverLink.id == link_id))
    if not link:
        raise HTTPException(status_code=404, detail="Permintaan tidak ditemukan")
    if link.status != LinkStatus.PENDING:
        raise HTTPException(status_code=400, detail="Permintaan sudah diproses")

    if link.initiated_by == "patient":
        if user.role != "caregiver" or user.id != link.caregiver_id:
            raise HTTPException(status_code=403, detail="Hanya caregiver penerima yang dapat menyetujui")
    elif link.initiated_by == "caregiver":
        if user.role != "patient" or user.id != link.patient_id:
            raise HTTPException(status_code=403, detail="Hanya pasien yang dapat menyetujui permintaan ini")
    else:
        raise HTTPException(status_code=400, detail="Permintaan tidak valid")

    link.status = LinkStatus.APPROVED
    await db.commit()
    await db.refresh(link)
    return LinkResponse.model_validate(link)


async def reject_link(db: AsyncSession, user: User, link_id: str) -> LinkResponse:
    link = await db.scalar(select(CaregiverLink).where(CaregiverLink.id == link_id))
    if not link:
        raise HTTPException(status_code=404, detail="Permintaan tidak ditemukan")
    if link.status != LinkStatus.PENDING:
        raise HTTPException(status_code=400, detail="Permintaan sudah diproses")

    if link.initiated_by == "patient":
        if user.role != "caregiver" or user.id != link.caregiver_id:
            raise HTTPException(status_code=403, detail="Hanya caregiver penerima yang dapat menolak")
    elif link.initiated_by == "caregiver":
        if user.role != "patient" or user.id != link.patient_id:
            raise HTTPException(status_code=403, detail="Hanya pasien yang dapat menolak permintaan ini")
    else:
        raise HTTPException(status_code=400, detail="Permintaan tidak valid")

    link.status = LinkStatus.REJECTED
    await db.commit()
    await db.refresh(link)
    return LinkResponse.model_validate(link)
