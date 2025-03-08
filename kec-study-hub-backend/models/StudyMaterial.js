const mongoose = require('mongoose');

// Define the schema
const studyMaterialSchema = new mongoose.Schema({
  subjectName: { type: String, required: true },
  materialType: { type: String, required: true },
  semester: { type: String, required: true },
  courseCode: { type: String, required: true },
  description: { type: String, default: '' },
  department: { type: String, required: true },
  year: { type: String, required: true },
  fileUrl: { type: String, required: true },
  uploadedBy: { type: String, required: true },
  uploadedAt: { type: Date, default: Date.now },
  reportCount: { type: Number, default: 0 },
  likes: { type: Number, default: 0 },
  views: { type: Number, default: 0 },
  downloads: { type: Number, default: 0 },
  likedBy: [{ type: String }],
  viewedBy: [{ type: String }],
  downloadedBy: [{ type: String }],
});

// Export the model, reusing it if already compiled
module.exports = mongoose.models.StudyMaterial || mongoose.model('StudyMaterial', studyMaterialSchema);