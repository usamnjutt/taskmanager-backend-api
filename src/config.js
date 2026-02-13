import dotenv from 'dotenv';
import path from 'path';

// Always try to load .env file, regardless of environment
try {
  dotenv.config({
    path: path.resolve(__dirname, '.env'),
    silent: true
  });
} catch (e) {
  console.error('Error loading .env:', e.message);
}

// Also log to help debugging
console.log('🔧 Config loaded. JWT_SECRET exists:', !!process.env.JWT_SECRET);

module.exports = {
  jwt_secret: process.env.JWT_SECRET || 'unsafe_jwt_secret',
  mongoose: {
    uri: process.env.MONGODB_URI || 'mongodb://localhost/mern'
  },
}
