const express = require('express');
const { uploadResource } = require('../controllers/resourceController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/upload', authMiddleware, uploadResource);

module.exports = router;