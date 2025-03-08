const Resource = require('../models/Resource');

const uploadResource = async (req, res) => {
  const { title, department, year, type, email } = req.body;
  const file = req.file;

  if (!title || !department || !year || !type || !file) {
    return res.status(400).json({ message: 'All fields and file are required' });
  }

  try {
    const resource = await Resource.create({
      title,
      department,
      year,
      type,
      filePath: file.path,
      uploadedBy: email,
    });

    res.status(201).json({ message: 'Resource uploaded', resource });
  } catch (error) {
    console.error('Error in uploadResource:', error.message);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = { uploadResource };