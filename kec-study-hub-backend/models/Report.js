const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  materialId: { type: mongoose.Schema.Types.ObjectId, ref: 'StudyMaterial', required: true },
  reportedBy: { type: String, required: true },
  reason: { type: String, required: true },
  reportedAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Report', reportSchema);