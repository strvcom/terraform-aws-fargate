const express = require('express')
const os = require('os')

const hostname = os.hostname()
const app = express()

app.listen(3000, () => console.log(`Example app listening on port 3000! Host: ${hostname}`))

app.get('/', async (req, res) => res.json({ hostname }))

app.get('/health-check', async (req, res) => res.json({ message: 'I am healthy 💊' }))
