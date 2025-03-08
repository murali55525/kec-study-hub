import express from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import bodyParser from 'body-parser';
import { Filter } from 'bad-words'; // Use named import
import { GoogleGenerativeAI } from '@google/generative-ai'; // Import Google Generative AI

const app = express();
const PORT = 3008;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('public')); // Serve static files from the public directory

// MongoDB Connection
mongoose.connect('mongodb://localhost:27017/discussion_forum', {
    useNewUrlParser: true,
    useUnifiedTopology: true,
})
    .then(() => console.log('MongoDB connected'))
    .catch(err => console.log(err));

// Message Schema
const messageSchema = new mongoose.Schema({
    sender: String,
    content: String,
    timestamp: { type: Date, default: Date.now },
    isGlobal: Boolean,
});

const Message = mongoose.model('Message', messageSchema);

// Initialize the filter
const filter = new Filter();

// Google Generative AI Setup
const API_KEY = 'AIzaSyC5evONEf7yvprota23Mqm0lt014jVg5sA'; // Replace with your actual API key
const genAI = new GoogleGenerativeAI(API_KEY);

// API Routes
// Get all global messages
app.get('/api/messages/global', async (req, res) => {
    const messages = await Message.find({ isGlobal: true }).sort({ timestamp: -1 });
    res.json(messages);
});

// Get all department messages by department
app.get('/api/messages/department/:department', async (req, res) => {
    const { department } = req.params;
    const messages = await Message.find({ isGlobal: false, sender: { $regex: department, $options: 'i' } })
        .sort({ timestamp: -1 });
    res.json(messages);
});

// Post a new message
app.post('/api/messages', async (req, res) => {
    let { sender, content, isGlobal } = req.body;

    // Apply bad words filter to the content
    if (filter.isProfane(content)) {
        return res.status(400).json({ message: 'Failed to send message. Content contains inappropriate language.' });
    }

    const message = new Message({ sender, content, isGlobal });
    await message.save();
    res.json(message);
});

// Endpoint to handle chat messages
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

// Serve the HTML file at the root endpoint
app.get('/c', (req, res) => {
    res.sendFile(__dirname + '/public/chatbot.html');
});

// Start server
app.listen(PORT, () => {
    console.log(`Server is running at http://localhost:${PORT}`);
});
