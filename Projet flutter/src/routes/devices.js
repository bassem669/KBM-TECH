const express = require("express");
const router = express.Router();
const controller = require("../controllers/userDeviceController");
const admin = require("firebase-admin");


router.post("/register", controller.registerDevice);
router.post("/assign", controller.assignToUser);
router.get("/user/:user_id", controller.getUserDevices);
router.delete("/:fcm_token", controller.deleteDevice);

module.exports = router;
