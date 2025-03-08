const Report = require('../models/Report');
const StudyMaterial = require('../models/StudyMaterial');

const reportMaterial = async (req, res) => {
  const { materialId, deviceId, reason } = req.body;

  if (!materialId || !deviceId || !reason) {
    return res.status(400).json({ message: 'Material ID, device ID, and reason are required' });
  }

  try {
    const report = await Report.create({
      materialId,
      reportedBy: deviceId,
      reason,
    });

    await StudyMaterial.findByIdAndUpdate(materialId, { $inc: { reportCount: 1 } });

    res.status(201).json({ message: 'Material reported successfully' });
  } catch (error) {
    console.error('Error reporting material:', error.message);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

const getReports = async (req, res) => {
  const { materialId } = req.params;

  try {
    const reports = await Report.find({ materialId });
    res.json(reports);
  } catch (error) {
    console.error('Error fetching reports:', error.message);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = { reportMaterial, getReports };