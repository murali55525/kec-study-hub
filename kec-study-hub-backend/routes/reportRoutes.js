const express = require('express');
const { reportMaterial, getReports } = require('../controllers/reportController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/', authMiddleware, reportMaterial);
router.get('/:materialId', authMiddleware, getReports);

module.exports = router;