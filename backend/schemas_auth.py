from pydantic import BaseModel, EmailStr
from typing import Optional

class LoginRequest(BaseModel):
    correo: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user_id: int
    user_name: str
    primer_login: Optional[bool] = False
