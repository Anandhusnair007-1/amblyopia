import asyncio
import uuid
from app.database import get_session_local
from app.models.nurse import Nurse
from sqlalchemy import select

async def seed():
    session_factory = get_session_local()
    async with session_factory() as session:
        # 1. Create Test Nurse
        nurse_id = uuid.UUID("00000000-0000-0000-0000-000000000001")
        result = await session.execute(select(Nurse).where(Nurse.id == nurse_id))
        if not result.scalar_one_or_none():
            nurse = Nurse(
                id=nurse_id,
                phone_number="1234567890",
                password_hash="static_hash", 
                device_id="test-device-001",
                is_active=True
            )
            session.add(nurse)
            print("Seeded test nurse")
            
        await session.commit()

if __name__ == "__main__":
    asyncio.run(seed())
