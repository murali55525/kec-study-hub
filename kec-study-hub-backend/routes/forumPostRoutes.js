const express = require('express');
const { getForumPosts, createForumPost } = require('../controllers/forumPostController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/', authMiddleware, getForumPosts);
router.post('/', authMiddleware, createForumPost);

module.exports = router;