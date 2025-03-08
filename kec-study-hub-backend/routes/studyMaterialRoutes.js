const express = require('express');
const router = express.Router();
const multer = require('multer');
const StudyMaterial = require('../models/StudyMaterial');
const authMiddleware = require('../middleware/authMiddleware');
const fs = require('fs');
const path = require('path');

// Configure multer to accept any file type
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${file.originalname}`;
    cb(null, uniqueName);
  },
});
const upload = multer({
  storage,
  // Optionally limit file size (e.g., 50MB)
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB limit
});

// Get all study materials
router.get('/', async (req, res) => {
  try {
    const { department, year } = req.query;
    const query = {};
    if (department && department !== 'All') query.department = department;
    if (year) query.year = year;

    const materials = await StudyMaterial.find(query).sort({ likes: -1 });
    res.status(200).json(materials);
  } catch (error) {
    console.error('Error fetching study materials:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Search study materials
router.get('/search', async (req, res) => {
  try {
    const { query } = req.query;
    if (!query) {
      return res.status(400).json({ message: 'Search query is required' });
    }

    const materials = await StudyMaterial.find({
      $or: [
        { subjectName: { $regex: query, $options: 'i' } },
        { courseCode: { $regex: query, $options: 'i' } },
        { description: { $regex: query, $options: 'i' } },
      ],
    }).sort({ likes: -1 });

    res.status(200).json(materials);
  } catch (error) {
    console.error('Error searching study materials:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Upload a study material (accepts any file type)
router.post('/', authMiddleware, upload.single('file'), async (req, res) => {
  const { subjectName, courseCode, materialType, semester, description, department, year, deviceId } = req.body;
  const file = req.file;

  console.log(`POST / received file: ${file ? file.originalname : 'none'}`);

  if (!subjectName || !courseCode || !materialType || !semester || !department || !year || !deviceId || !file) {
    return res.status(400).json({ message: 'All fields and file are required' });
  }

  try {
    const fileUrl = `http://localhost:5000/uploads/${file.filename}`;
    const material = await StudyMaterial.create({
      subjectName,
      courseCode,
      materialType,
      semester,
      description: description || '',
      department,
      year,
      fileUrl,
      uploadedBy: deviceId,
    });

    console.log(`Created material with fileUrl: ${fileUrl}`);
    res.status(201).json(material);
  } catch (error) {
    console.error('Error uploading study material:', error.message);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update a study material (with file replacement, accepts any file type)
router.put('/:id', authMiddleware, upload.single('file'), async (req, res) => {
  try {
    const { subjectName, courseCode, materialType, semester, description, department, year, uploadedBy } = req.body;
    const file = req.file;

    if (!subjectName || !courseCode || !materialType || !semester || !department || !year || !uploadedBy) {
      return res.status(400).json({ message: 'All fields are required except description and file' });
    }

    const material = await StudyMaterial.findById(req.params.id);
    if (!material) return res.status(404).json({ message: 'Material not found' });

    // Allow admin to edit any material, regardless of uploadedBy
    if (!req.user.isAdmin && material.uploadedBy !== uploadedBy) {
      return res.status(403).json({ message: 'You can only edit your own materials' });
    }

    if (file) {
      const oldFilePath = path.join(__dirname, '..', 'uploads', material.fileUrl.split('/uploads/')[1]);
      if (fs.existsSync(oldFilePath)) fs.unlinkSync(oldFilePath);
      material.fileUrl = `http://localhost:5000/uploads/${file.filename}`;
    }

    material.subjectName = subjectName;
    material.courseCode = courseCode;
    material.materialType = materialType;
    material.semester = semester;
    material.description = description || '';
    material.department = department;
    material.year = year;

    await material.save();
    res.status(200).json(material);
  } catch (error) {
    console.error('Error updating study material:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete a study material
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const { deviceId } = req.body;
    if (!deviceId) return res.status(400).json({ message: 'Device ID is required in body' });

    const material = await StudyMaterial.findById(req.params.id);
    if (!material) return res.status(404).json({ message: 'Material not found' });

    // Allow admin to delete any material, regardless of uploadedBy
    if (!req.user.isAdmin && material.uploadedBy !== deviceId) {
      return res.status(403).json({ message: 'You can only delete your own materials' });
    }

    const filePath = path.join(__dirname, '..', 'uploads', material.fileUrl.split('/uploads/')[1]);
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);

    await StudyMaterial.deleteOne({ _id: req.params.id });
    res.status(200).json({ message: 'Material deleted successfully' });
  } catch (error) {
    console.error('Error deleting study material:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Like a study material
router.post('/:id/like', authMiddleware, async (req, res) => {
  try {
    const deviceId = req.body.deviceId;
    if (!deviceId) {
      return res.status(400).json({ message: 'Device ID is required' });
    }

    const material = await StudyMaterial.findById(req.params.id);
    if (!material) {
      return res.status(404).json({ message: 'Material not found' });
    }

    if (material.likedBy.includes(deviceId)) {
      return res.status(400).json({ message: 'This device has already liked this resource' });
    }

    material.likedBy.push(deviceId);
    material.likes = (material.likes || 0) + 1;
    await material.save();
    res.status(200).json(material);
  } catch (error) {
    console.error('Error liking material:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// View a study material
router.post('/:id/view', authMiddleware, async (req, res) => {
  try {
    const deviceId = req.body.deviceId;
    if (!deviceId) {
      return res.status(400).json({ message: 'Device ID is required' });
    }

    const material = await StudyMaterial.findById(req.params.id);
    if (!material) {
      return res.status(404).json({ message: 'Material not found' });
    }

    if (material.viewedBy.includes(deviceId)) {
      return res.status(400).json({ message: 'This device has already viewed this resource' });
    }

    material.viewedBy.push(deviceId);
    material.views = (material.views || 0) + 1;
    await material.save();
    res.status(200).json(material);
  } catch (error) {
    console.error('Error incrementing view:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});
// ... (existing imports and code)

// Fetch materials uploaded by a user
router.get('/user-materials', authMiddleware, async (req, res) => {
  try {
    const { deviceId } = req.query;
    if (!deviceId) {
      return res.status(400).json({ message: 'Device ID is required' });
    }
    const materials = await StudyMaterial.find({ uploadedBy: deviceId }).sort({ uploadedAt: -1 });
    console.log(`Fetched ${materials.length} materials for deviceId: ${deviceId}`);
    res.status(200).json(materials);
  } catch (error) {
    console.error('Error fetching user materials:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// ... (existing routes like POST, PUT, DELETE remain unchanged)
// Download a study material
router.post('/:id/download', authMiddleware, async (req, res) => {
  try {
    const deviceId = req.body.deviceId;
    if (!deviceId) {
      return res.status(400).json({ message: 'Device ID is required' });
    }

    const material = await StudyMaterial.findById(req.params.id);
    if (!material) {
      return res.status(404).json({ message: 'Material not found' });
    }

    if (!material.downloadedBy.includes(deviceId)) {
      material.downloadedBy.push(deviceId);
      material.downloads = (material.downloads || 0) + 1;
      await material.save();
    }

    res.status(200).json(material);
  } catch (error) {
    console.error('Error incrementing download:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;