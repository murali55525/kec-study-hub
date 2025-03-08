const express = require('express');
const { addUser, loginUser, bulkAddUsers } = require('../controllers/userController');
const authMiddleware = require('../middleware/authMiddleware');
const multer = require('multer');

const router = express.Router();

// Multer setup for CSV uploads
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage });

router.post('/login', loginUser);
router.post('/add-user', authMiddleware, addUser);
router.post('/bulk-add-users', authMiddleware, upload.single('csvFile'), bulkAddUsers);

module.exports = router;