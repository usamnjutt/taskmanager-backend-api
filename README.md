# MERN Backend API

## Setup
1. Install dependencies: `npm install`
2. Create `.env` file (copy from `.env.example`)
3. Start MongoDB: `sudo systemctl start mongodb`
4. Run: `npm start`

## API Endpoints
- `GET /api/users` - Get all users
- `POST /api/users/register` - Register user
- `POST /api/users/login` - Login user
- `GET /api/current_user` - Get current user (requires auth)

## Deployment
Auto-deployed via GitHub Actions runner
