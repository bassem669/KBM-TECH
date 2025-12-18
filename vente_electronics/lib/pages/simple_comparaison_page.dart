// pages/simple_comparison_page.dart
import 'package:flutter/material.dart';
import '../fetch/comparison_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SimpleComparisonPage extends StatefulWidget {
  final List<int> productIds;

  const SimpleComparisonPage({Key? key, required this.productIds}) : super(key: key);

  @override
  _SimpleComparisonPageState createState() => _SimpleComparisonPageState();
}

class _SimpleComparisonPageState extends State<SimpleComparisonPage> {
  static String baseUrl = dotenv.env['IMAGE_URL'] ?? 'http://192.168.1.54:5000/api/';

  late Future<Map<String, dynamic>> _comparisonFuture;
  Map<String, dynamic>? _comparisonData;

  @override
  void initState() {
    super.initState();
    _comparisonFuture = ComparisonService.compareProducts(widget.productIds);
  }

  void _refreshComparison() {
    setState(() {
      _comparisonFuture = ComparisonService.compareProducts(widget.productIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Comparison'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshComparison,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _comparisonFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.hasData) {
            _comparisonData = snapshot.data!;
            return _buildComparisonTable();
          }

          return const Center(child: Text('No data available'));
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyzing products with AI...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to load comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(error),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshComparison,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable() {
    final products = _comparisonData!['produits'] as List;
    final comparisonData = _comparisonData!['comparaison'] as Map<String, dynamic>;
    final productComparisons = comparisonData['comparition'] as List;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Product Headers
            _buildProductHeaders(products, productComparisons),
            const SizedBox(height: 20),

            // Price Row
            _buildPriceRow(products),
            const SizedBox(height: 20),

            // Description Section
            _buildComparisonSection('Description', productComparisons, 'description'),
            const SizedBox(height: 20),

            // Specifications Table
            _buildSpecsTable(productComparisons),
            const SizedBox(height: 20),

            // Features
            _buildComparisonSectionWithList('Caracteristiques', productComparisons, 'features'),
            const SizedBox(height: 20),

            // Strengths
            _buildComparisonSectionWithList('Points forts', productComparisons, 'strengths'),
            const SizedBox(height: 20),

            // Weaknesses
            _buildComparisonSectionWithList('Points faibles', productComparisons, 'weaknesses'),
            const SizedBox(height: 20),

            // Who Should Buy
            _buildComparisonSection('Qui devrait acheter', productComparisons, 'who_should_buy'),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeaders(List products, List productComparisons) {
    return Row(
      children: List.generate(products.length, (index) {
        final product = products[index];
        final productComparison = productComparisons[index];
        
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  productComparison['product_name'] ?? 'Unknown Product',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Affichage de l'image si disponible
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: product['images'] != null && 
                         (product['images'] as List).isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '$baseUrl${product['images'][0]["path"]}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.phone_android, color: Colors.grey);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          ),
                        )
                      : const Icon(Icons.phone_android, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPriceRow(List products) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: products.map((product) {
          return Column(
            children: [
              Text(
                product['nom'],
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${product['prix'].toStringAsFixed(2)} DNT',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              // Stock information
              Text(
                product['quantite'] > 0 ? 'In Stock' : 'Out of Stock',
                style: TextStyle(
                  color: product['quantite'] > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSpecsTable(List productComparisons) {
    final specTitles = ['RAM', 'Storage', 'Battery', 'Processor', 'Display'];
    final specKeys = ['ram', 'storage', 'battery', 'processor', 'display'];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(width: 100),
                Expanded(
                  child: Text(
                    'Specifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Spec Rows
          ...List.generate(specTitles.length, (index) {
            return Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
                color: index % 2 == 0 ? Colors.white : Colors.grey[50],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spec Title
                  Container(
                    width: 100,
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey[100],
                    child: Text(
                      specTitles[index],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Product Specs
                  ...productComparisons.map((product) {
                    final specs = product['specs'] as Map<String, dynamic>;
                    final specValue = specs[specKeys[index]] ?? 'N/A';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          specValue.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComparisonSection(String title, List productComparisons, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: productComparisons.map((product) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  product[key] ?? 'No information available',
                  textAlign: TextAlign.justify,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildComparisonSectionWithList(String title, List productComparisons, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: productComparisons.map((product) {
            final items = product[key] as List<dynamic>? ?? [];
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              item.toString(),
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                    if (items.isEmpty) 
                      Text(
                        'No data available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}