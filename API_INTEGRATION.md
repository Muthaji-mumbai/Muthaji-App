# Soloshine API Integration

## Overview
This Flutter app is now integrated with the Soloshine backend API at `https://soloshine-backend.onrender.com`.

## API Endpoints

### Authentication
- **Login**: `POST /auth/login`
  - Request Body: `{"email": "codoit53@gmail.com", "password": "123456"}`
  - Response: User data with role and JWT token

## User Roles
The app supports three user roles based on the backend response:
- **Admin**: Full system access
- **Employee**: Order management and client creation
- **Client**: Order creation and history viewing

## Demo Credentials
- **Email**: `codoit53@gmail.com`
- **Password**: `123456`
- **Note**: Role is determined by the backend response

## Features Implemented

### 1. API Service (`lib/services/api_service.dart`)
- Generic HTTP methods (GET, POST, PUT, DELETE)
- Automatic token handling
- Error handling and response parsing

### 2. Updated Auth Service (`lib/services/auth_service.dart`)
- Real API integration instead of mock data
- JWT token storage
- Local storage persistence

### 3. Enhanced User Model (`lib/models/user.dart`)
- Support for API response structure
- Token field for authentication
- Flexible role parsing

### 4. Role-Based Navigation
- **Admin Dashboard**: System overview, user management, order management
- **Employee Dashboard**: Order management, client creation
- **Client Dashboard**: Order creation, history viewing

## How to Use

1. **Login**: Use the demo credentials provided
2. **Role Detection**: The app automatically detects your role from the API response
3. **Navigation**: Based on your role, you'll be redirected to the appropriate dashboard
4. **Token Management**: JWT tokens are automatically handled and stored

## Technical Details

### API Response Structure
```json
{
  "success": true,
  "data": {
    "_id": "user_id",
    "email": "user@example.com",
    "role": "admin|employee|customer",
    "token": "jwt_token_here"
  },
  "message": "Login Successfully"
}
```

### Error Handling
- Network errors are caught and displayed to the user
- API error messages are shown in snackbars
- Graceful fallbacks for missing user data

### Local Storage
- User data and tokens are persisted locally
- Automatic login on app restart if token is valid

## Future Enhancements
- User profile management
- Order CRUD operations
- Real-time updates
- Push notifications
- Offline support

## Dependencies
- `http`: For API communication
- `shared_preferences`: For local storage
- `provider`: For state management
- `responsive_framework`: For responsive design
