const express = require('express');
const router = express.Router();
const {
  createPromotion,
  getAllPromotions,
  getPromotionById,
  updatePromotion,
  deletePromotion,
  getActivePromotions,
  removeProductFromPromotion,
  removeProductsFromPromotion,
  applyPromotionToAllProducts,          // Nouveau
  applyPromotionToCategory,             // Nouveau
  updatePromotionForAllProducts,     // 🔹 Nouveau
  updatePromotionForCategories   
} = require('../controllers/promotionController');
const { authenticate, isAdmin } = require('../middleware/auth');


router.use(authenticate);        // Toutes les routes suivantes nécessitent un token
router.use(isAdmin);     // Et le rôle admin
// CRUD
router.post('/', createPromotion);
router.get('/', getAllPromotions);
router.get('/active', getActivePromotions);
router.get('/:id', getPromotionById);
router.put('/:id', updatePromotion);
router.delete('/:id', deletePromotion);

router.delete('/:promotionId/produits/:produitId', removeProductFromPromotion);
router.delete('/:promotionId/produits', removeProductsFromPromotion);


router.post('/apply-to-all', applyPromotionToAllProducts);
router.post('/apply-to-category', applyPromotionToCategory);
router.put('/:promotionId/updateCategory', updatePromotionForCategories);
router.put('/:promotionId/toAll', updatePromotionForAllProducts);

module.exports = router;
