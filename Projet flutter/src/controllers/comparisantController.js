const { GoogleGenerativeAI } = require("@google/generative-ai");
const Produit = require("../models/Produit");
const Image = require("../models/Image");
require("dotenv").config();

exports.compare = async (req, res) => {
  try {
    let { produitIds } = req.query;

    if (!produitIds) {
      return res.status(400).json({ message: "Aucun produit spécifié pour la comparaison" });
    }

    if (produitIds.startsWith("[")) {
      produitIds = JSON.parse(produitIds);
    } else {
      produitIds = produitIds.split(",").map((id) => parseInt(id));
    }

    const produits = await Produit.findAll({
      where: { id: produitIds },
      include: [
        {
          model: Image,
          as: 'images',          // l’alias défini dans le modèle Produit.hasMany(Image, { as: 'images' })
          attributes: ['id', 'path'],
          limit: 1               // récupère seulement la première image
        }
      ]
    });


    if (produits.length === 0) {
      return res.status(404).json({ message: "Aucun produit trouvé" });
    }

    // 1️⃣ Initialisation correct
    const genAI = new GoogleGenerativeAI(process.env.AI_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    // 2️⃣ Prompt propre
    const productList = produits
      .map((p) => `- ${p.nom}`)
      .join("\n");

    const prompt = `
      Tu es un modèle d’IA qui doit impérativement renvoyer les données dans un format JSON fixe et immuable.

      Ta tâche : Comparer des produits électroniques en utilisant des paragraphes courts et en mettant en avant les différences importantes.

      ⚠️ RÈGLES OBLIGATOIRES :
      - La sortie doit être UNIQUEMENT du JSON valide.
      - Aucun texte avant ou après le JSON.
      - Ne jamais renommer, réordonner ou supprimer des clés.
      - Toujours garder la même structure, même si certaines informations sont manquantes.
      - Chaque section doit contenir un paragraphe court et clair.
      - Les specs doivent contenir EXCLUSIVEMENT : ram, storage, battery, processor, display.

      Voici le FORMAT JSON EXACT que tu dois renvoyer :

      {
        "comparition": [
          {
            "product_name": "",
            "description": "",
            "specs": {
              "ram": "",
              "storage": "",
              "battery": "",
              "processor": "",
              "display": ""
            },
            "features": [],
            "strengths": [],
            "weaknesses": [],
            "who_should_buy": ""
          }
        ]
      }

      Maintenant, compare les produits suivants et remplis STRICTEMENT ce JSON avec les données correspondantes :

      Produits :
      ${productList}
        `;

    // 3️⃣ AI Call correct
    const result = await model.generateContent(prompt);

    let rawResponse = result.response.text(); // ce que Gemini retourne

    // 1️⃣ Supprimer les ```json et ``` autour
    rawResponse = rawResponse.replace(/```json/, "").replace(/```/g, "").trim();

    // 2️⃣ Maintenant, rawResponse est du JSON valide, on peut parser
    let data;
    try {
    data = JSON.parse(rawResponse);
    } catch (err) {
        console.error("Erreur JSON :", err);
        console.log("Contenu brut :", rawResponse);
    }
    res.json({
      produits,
      comparaison: data,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
