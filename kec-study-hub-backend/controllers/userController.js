const User = require('../models/User');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { parse } = require('csv-parse');
const fs = require('fs');
const nodemailer = require('nodemailer');

// Email transporter setup
const transporter = nodemailer.createTransport({
  service: 'gmail', // Replace with your SMTP service
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

// Generate random password
const generatePassword = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#$';
  let password = '';
  for (let i = 0; i < 10; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return password;
};

// Login user
const loginUser = async (req, res) => {
  const { email, password } = req.body;
  try {
    const user = await User.findOne({ email });
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // Determine admin status (hardcoded for admin@kongu.edu or from DB)
    const isAdmin = email === 'admin@kongu.edu' || user.isAdmin || false;

    const token = jwt.sign(
      {
        id: user._id,
        name: user.name,
        email: user.email,
        isAdmin: isAdmin, // Add isAdmin to token payload
      },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.status(200).json({ _id: user._id, name: user.name, email: user.email, token });
  } catch (error) {
    console.error('Error logging in:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Add single user
const addUser = async (req, res) => {
  const { name, email } = req.body;
  try {
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }
    const password = generatePassword();
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ name, email, password: hashedPassword });
    await user.save();

    await transporter.sendMail({
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'KEC Study Hub Account Created',
      text: `Your account has been created. Your password is: ${password}`,
    });

    res.status(201).json({ message: 'User added and email sent', email, password });
  } catch (error) {
    console.error('Error adding user:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Bulk add users from CSV
const bulkAddUsers = async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: 'No CSV file uploaded' });
  }

  const results = [];
  const errors = [];
  const filePath = req.file.path;

  fs.createReadStream(filePath)
    .pipe(parse({ columns: true, trim: true }))
    .on('data', async (row) => {
      try {
        const { name, email } = row;

        // Validate email
        if (!email.endsWith('@kongu.edu')) {
          throw new Error('Only @kongu.edu emails are allowed');
        }

        // Check if user exists
        const existingUser = await User.findOne({ email });
        if (existingUser) {
          throw new Error('User already exists');
        }

        // Generate and hash password
        const password = generatePassword();
        const hashedPassword = await bcrypt.hash(password, 10);

        // Create user
        const newUser = new User({ name, email, password: hashedPassword });
        await newUser.save();

        // Send email
        await transporter.sendMail({
          from: process.env.EMAIL_USER,
          to: email,
          subject: 'KEC Study Hub Account Created',
          text: `Your account has been created. Your password is: ${password}`,
        });

        results.push({ email, message: 'User added and email sent' });
      } catch (error) {
        errors.push({ email: row.email, message: error.message });
      }
    })
    .on('end', () => {
      fs.unlinkSync(filePath); // Clean up file
      res.status(errors.length && !results.length ? 400 : 201).json({
        message: 'Bulk add processed',
        results,
        errors,
      });
    })
    .on('error', (err) => {
      fs.unlinkSync(filePath);
      res.status(500).json({ message: 'Error processing CSV', error: err.message });
    });
};

module.exports = { addUser, loginUser, bulkAddUsers };