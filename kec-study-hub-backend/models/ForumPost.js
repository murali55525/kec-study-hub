const mongoose = require('mongoose');

const forumPostSchema = new mongoose.Schema({
  text: { type: String, required: true },
  userId: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
});

module.exports = mongoose.model('ForumPost', forumPostSchema);