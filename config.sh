# ==========================
# SMTP Server Configuration
# ==========================
SMTP_SERVER="localhost"
SMTP_PORT="587"
USERNAME="test@test.local"
PASSWORD="password123"

# ==========================
# Default Email Headers (overridable per dataset via headers.txt)
# ==========================
FROM_NAME="Test Sender"
FROM="test@test.local"
TO="receiver@test.local"
SUBJECT="Product issue detected"