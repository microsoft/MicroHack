/*
Execute to initialize:
npm init
(fill in data)

npm install <module>
for this: 
npm install
npm install express
npm install cors
 */

const express = require('express');
const cors = require('cors')
const app = express()
app.use(cors())
port = 3000;

app.use(express.json());

const unmodifiedSeatList = [
    {
        "name": "1A",
        "status": "free",
    },
    {
        "name": "1B",
        "status": "free",
    },
    {
        "name": "1C",
        "status": "free",
    },
    {
        "name": "2A",
        "status": "free",
    },
    {
        "name": "2B",
        "status": "free",
    },
    {
        "name": "2C",
        "status": "free",
    },
    {
        "name": "3A",
        "status": "free",
    },
    {
        "name": "3B",
        "status": "free",
    },
    {
        "name": "3C",
        "status": "free",
    },
]

let seatList = [
    {
        "name": "1A", 
        "status": "free",
    },
    {
        "name": "1B",
        "status": "free",
    },
    {
        "name": "1C",
        "status": "free",
    },
    {
        "name": "2A",
        "status": "free",
    },
    {
        "name": "2B",
        "status": "free",
    },
    {
        "name": "2C",
        "status": "free",
    },
    {
        "name": "3A",
        "status": "free",
    },
    {
        "name": "3B",
        "status": "free",
    },
    {
        "name": "3C",
        "status": "free",
    },
]
app.get('/api/seats', (req, res) => {
    res.send(seatList)
})

app.post('/api/seat', (req, res) => {
    console.log(req.body);
    seatList = req.body["seat"];
    res.send(seatList)
})

app.get('/api/reset', (req, res) => {
    seatList = unmodifiedSeatList
    res.send(seatList)
})

app.listen(port, () => {
    console.log(`Example app listening on port ${port}`)
})

