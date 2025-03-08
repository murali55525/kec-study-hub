const ForumPost = require('../models/ForumPost');

const getForumPosts = async (req, res) => {
  try {
    const posts = await ForumPost.find().sort({ timestamp: -1 });
    res.json(posts);
  } catch (error) {
    console.error('Error fetching forum posts:', error.message);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

const createForumPost = async (req, res) => {
  const { text, deviceId } = req.body;

  if (!text || !deviceId) {
    return res.status(400).json({ message: 'Text and deviceId are required' });
  }

  try {
    const post = await ForumPost.create({
      text,
      userId: deviceId,
    });
    res.status(201).json(post);
  } catch (error) {
    console.error('Error creating forum post:', error.message);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = { getForumPosts, createForumPost };