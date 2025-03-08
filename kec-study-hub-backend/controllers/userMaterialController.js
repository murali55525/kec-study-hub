const StudyMaterial = require('../models/StudyMaterial');

const getUserMaterials = async (req, res) => {
  const { deviceId } = req.query;

  if (!deviceId) {
    return res.status(400).json({ message: 'Device ID is required' });
  }

  try {
    const materials = await StudyMaterial.find({ uploadedBy: deviceId });
    res.json(materials);
  } catch (error) {
    console.error('Error fetching user materials:', error.message);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = { getUserMaterials };