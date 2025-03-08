const express = require('express');
const { getUserMaterials } = require('../controllers/userMaterialController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/', authMiddleware, getUserMaterials);

module.exports = router;