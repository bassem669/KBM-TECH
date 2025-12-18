// routes/produitRoutes.js
const express = require('express');
const router = express.Router();
const produitController = require('../controllers/produitController');
const { authenticate, isAdmin } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// 📂 Configuration Multer pour upload d'images
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = path.join(__dirname, '../uploads');
    if (!fs.existsSync(uploadPath)) fs.mkdirSync(uploadPath, { recursive: true });
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const filename = `${Date.now()}-${Math.round(Math.random() * 1E9)}${ext}`;
    cb(null, filename);
  }
});

// Dans produits.js - MODIFIEZ le fileFilter
const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {    
    const allowedExtensions = ['.jpeg', '.jpg', '.png', '.webp'];
    const allowedMimes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/octet-stream'];
    
    const fileExtension = path.extname(file.originalname).toLowerCase();
    const hasValidExtension = allowedExtensions.includes(fileExtension);
    const hasValidMime = allowedMimes.includes(file.mimetype);
    
    
    if (hasValidExtension && hasValidMime) {
      console.log('✅ FICHIER ACCEPTÉ');
      return cb(null, true);
    } else {

      return cb(new Error(`Image invalide (JPEG, PNG, WEBP uniquement). Reçu: ${file.mimetype} - ${fileExtension}`));
    }
  }
});

// === ROUTES PUBLIQUES ===
router.get('/plusNotes', produitController.getPlusNotes);
router.get('/plusPopulaires', produitController.getPlusPopulaires);
router.get('/', produitController.getAll);
router.get('/:id', produitController.getById);

// === ROUTES ADMIN (protégées) ===
router.use(authenticate);
router.use(isAdmin);

router.post('/', upload.array('images', 10), produitController.create);
router.put('/:id', upload.array('images', 10), produitController.update);
router.delete('/:id', produitController.remove);


router.get('/:id/images', authenticate, isAdmin, produitController.getProductImages);
router.post('/:id/images', upload.single('image'), produitController.uploadImage);
router.delete('/:id/images/:imageId', produitController.deleteImage);

module.exports = router;
