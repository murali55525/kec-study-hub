import express from 'express';
import dotenv from 'dotenv';
import cors from 'cors';
import mongoose from 'mongoose';
import multer from 'multer';
import path from 'path';
import { Filter } from 'bad-words'; // Use named import for ES Modules
import { GoogleGenerativeAI } from '@google/generative-ai';

// Load environment variables
dotenv.config();

// Initialize Express app
const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));
app.use(express.static('public')); // For chatbot HTML and static files

// Multer setup for file uploads
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage });

// MongoDB Connection for KEC Study Hub and Discussion Forum
mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/kec_study_hub', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
  .then(() => console.log('Connected to MongoDB (KEC Study Hub)'))
  .catch(err => console.log('MongoDB connection error:', err));

// Message Schema for Discussion Forum
const messageSchema = new mongoose.Schema({
  sender: String,
  content: String,
  timestamp: { type: Date, default: Date.now },
  isGlobal: Boolean,
});

const Message = mongoose.model('Message', messageSchema);

// Initialize the profanity filter
const filter = new Filter();

// Google Generative AI Setup
const API_KEY = process.env.GOOGLE_AI_API_KEY || 'AIzaSyC5evONEf7yvprota23Mqm0lt014jVg5sA'; // Replace with your actual API key
const genAI = new GoogleGenerativeAI(API_KEY);

// Routes for KEC Study Hub
app.use('/api/users', (await import('./routes/userRoutes.js')).default);
app.use('/api/resources', upload.single('file'), (await import('./routes/resourceRoutes.js')).default);
app.use('/study-materials', (await import('./routes/studyMaterialRoutes.js')).default);
app.use('/forum-posts', (await import('./routes/forumPostRoutes.js')).default);
app.use('/report-material', (await import('./routes/reportRoutes.js')).default);
app.use('/user-materials', (await import('./routes/userMaterialRoutes.js')).default);
app.use('/reports', (await import('./routes/reportRoutes.js')).default);

// Routes for Discussion Forum
app.get('/api/messages/global', async (req, res) => {
  const messages = await Message.find({ isGlobal: true }).sort({ timestamp: -1 });
  res.json(messages);
});

app.get('/api/messages/department/:department', async (req, res) => {
  const { department } = req.params;
  const messages = await Message.find({ isGlobal: false, sender: { $regex: department, $options: 'i' } })
    .sort({ timestamp: -1 });
  res.json(messages);
});

app.post('/api/messages', async (req, res) => {
  let { sender, content, isGlobal } = req.body;

  // Apply profanity filter
  if (filter.isProfane(content)) {
    return res.status(400).json({ message: 'Failed to send message. Content contains inappropriate language.' });
  }

  const message = new Message({ sender, content, isGlobal });
  await message.save();
  res.json(message);
});

// Chatbot Endpoint
app.post('/chat', async (req, res) => {
  const userMessage = req.body.message;
  if (userMessage) {
    try {
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
      const result = await model.generateContent([userMessage]);
      const reply = result.response.text();
      res.json({ reply });
    } catch (error) {
      console.error("Error:", error);
      res.status(500).json({ error: "An error occurred while processing your request." });
    }
  } else {
    res.status(400).json({ error: "No message provided." });
  }
});

// Serve the chatbot HTML file
app.get('/c', (req, res) => {
  res.sendFile(path.join(process.cwd(), 'public', 'chatbot.html'));
});

// Root endpoint
app.get('/', (req, res) => {
  res.send('KEC Study Hub and Discussion Forum API is running...');
});

// Start the server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});