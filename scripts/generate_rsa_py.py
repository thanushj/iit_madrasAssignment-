from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from pathlib import Path

keys_dir = Path("keys")
keys_dir.mkdir(exist_ok=True)

priv = rsa.generate_private_key(public_exponent=65537, key_size=2048)
priv_pem = priv.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.TraditionalOpenSSL,
    encryption_algorithm=serialization.NoEncryption(),
)
pub_pem = priv.public_key().public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)

(keys_dir / "private.pem").write_bytes(priv_pem)
(keys_dir / "public.pem").write_bytes(pub_pem)

print("Wrote keys/private.pem and keys/public.pem — do NOT commit private.pem.")
