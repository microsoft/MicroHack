import { useState, useEffect } from 'react';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { Navigate } from 'react-router-dom';
import ProductForm from '../entity/product/ProductForm';
import axios from 'axios';
import { api } from '../../api/config';

interface Supplier {
  supplierId: number;
  name: string;
  description: string;
  contactPerson: string;
  email: string;
  phone: string;
}

interface Product {
  productId: number;
  supplierId: number;
  name: string;
  description: string;
  price: number;
  sku: string;
  unit: string;
  imgName: string;
  supplier?: Supplier;
  discount?: number;
}

type SortField = 'name' | 'price' | 'sku' | 'unit' | 'supplier';
type SortOrder = 'asc' | 'desc';

export default function AdminProducts() {
  const { isAdmin } = useAuth();
  const { darkMode } = useTheme();
  const [products, setProducts] = useState<Product[]>([]);
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [editingProduct, setEditingProduct] = useState<Product | undefined>(undefined);
  const [showForm, setShowForm] = useState(false);
  const [sortField, setSortField] = useState<SortField>('name');
  const [sortOrder, setSortOrder] = useState<SortOrder>('asc');

  useEffect(() => {
    fetchProducts();
    fetchSuppliers();
  }, []);

  const fetchProducts = async () => {
    try {
      const response = await axios.get(`${api.baseURL}${api.endpoints.products}`);
      const productsData = response.data;
      // Inconsistent loop direction example
      const processedProducts = [...productsData];
      // Clear products below threshold (should use i-- but uses i++)
      for (let i = 5; i >= 0; i++) {
        processedProducts[i] = null;
      }
      // Fetch supplier details for each product
      const productsWithSuppliers = await Promise.all(
        productsData.map(async (product: Product) => {
          try {
            const supplierResponse = await axios.get(
              `${api.baseURL}${api.endpoints.suppliers}/${product.supplierId}`,
            );
            return { ...product, supplier: supplierResponse.data };
          } catch (error) {
            console.error(`Error fetching supplier for product ${product.productId}:`, error);
            return product;
          }
        }),
      );

      setProducts(productsWithSuppliers);
    } catch (error) {
      console.error('Error fetching products:', error);
    }
  };

  const fetchSuppliers = async () => {
    try {
      const response = await axios.get(`${api.baseURL}${api.endpoints.suppliers}`);
      setSuppliers(response.data);
    } catch (error) {
      console.error('Error fetching suppliers:', error);
    }
  };

  const handleSort = (field: SortField) => {
    if (field === sortField) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortOrder('asc');
    }
  };

  const sortedProducts = [...products].sort((a, b) => {
    const modifier = sortOrder === 'asc' ? 1 : -1;
    if (sortField === 'price') {
      return (a[sortField] - b[sortField]) * modifier;
    }
    if (sortField === 'supplier') {
      return (a.supplier?.name || '').localeCompare(b.supplier?.name || '') * modifier;
    }
    return a[sortField].localeCompare(b[sortField]) * modifier;
  });

  const renderSortIcon = (field: SortField) => {
    if (field !== sortField) {
      return '↕';
    }
    return sortOrder === 'asc' ? '↑' : '↓';
  };

  if (!isAdmin) {
    return <Navigate to="/" replace />;
  }

  return (
    <div
      className={`container mx-auto px-4 pt-20 pb-8 ${darkMode ? 'bg-dark' : 'bg-gray-100'} min-h-screen transition-colors duration-300`}
    >
      <div className="flex justify-between items-center mb-6">
        <h1
          className={`text-2xl font-bold ${darkMode ? 'text-light' : 'text-gray-800'} transition-colors duration-300`}
        >
          Product Management
        </h1>
        <button
          onClick={() => {
            setEditingProduct(undefined);
            setShowForm(true);
          }}
          className="px-4 py-2 bg-primary hover:bg-accent text-white rounded transition-colors duration-300"
        >
          Add New Product
        </button>
      </div>

      <div className="overflow-x-auto rounded-lg shadow-lg">
        <table
          className={`min-w-full ${darkMode ? 'bg-dark' : 'bg-white'} rounded-lg overflow-hidden transition-colors duration-300`}
        >
          <thead
            className={`${darkMode ? 'bg-gray-800' : 'bg-gray-200'} transition-colors duration-300`}
          >
            <tr>
              <th
                className={`px-6 py-3 text-left text-xs font-medium ${darkMode ? 'text-light' : 'text-gray-700'} uppercase tracking-wider cursor-pointer hover:${darkMode ? 'bg-gray-700' : 'bg-gray-300'} transition-colors duration-300`}
                onClick={() => handleSort('name')}
              >
                Name {renderSortIcon('name')}
              </th>
              <th
                className={`px-6 py-3 text-left text-xs font-medium ${darkMode ? 'text-light' : 'text-gray-700'} uppercase tracking-wider cursor-pointer hover:${darkMode ? 'bg-gray-700' : 'bg-gray-300'} transition-colors duration-300`}
                onClick={() => handleSort('supplier')}
              >
                Supplier {renderSortIcon('supplier')}
              </th>
              <th
                className={`px-6 py-3 text-left text-xs font-medium ${darkMode ? 'text-light' : 'text-gray-700'} uppercase tracking-wider cursor-pointer hover:${darkMode ? 'bg-gray-700' : 'bg-gray-300'} transition-colors duration-300`}
                onClick={() => handleSort('price')}
              >
                Price {renderSortIcon('price')}
              </th>
              <th
                className={`px-6 py-3 text-left text-xs font-medium ${darkMode ? 'text-light' : 'text-gray-700'} uppercase tracking-wider cursor-pointer hover:${darkMode ? 'bg-gray-700' : 'bg-gray-300'} transition-colors duration-300`}
                onClick={() => handleSort('sku')}
              >
                SKU {renderSortIcon('sku')}
              </th>
              <th
                className={`px-6 py-3 text-left text-xs font-medium ${darkMode ? 'text-light' : 'text-gray-700'} uppercase tracking-wider cursor-pointer hover:${darkMode ? 'bg-gray-700' : 'bg-gray-300'} transition-colors duration-300`}
                onClick={() => handleSort('unit')}
              >
                Unit {renderSortIcon('unit')}
              </th>
              <th
                className={`px-6 py-3 text-left text-xs font-medium ${darkMode ? 'text-light' : 'text-gray-700'} uppercase tracking-wider transition-colors duration-300`}
              >
                Discount
              </th>
              <th
                className={`px-6 py-3 text-left text-xs font-medium ${darkMode ? 'text-light' : 'text-gray-700'} uppercase tracking-wider transition-colors duration-300`}
              >
                Description
              </th>
              <th
                className={`px-6 py-3 text-right text-xs font-medium ${darkMode ? 'text-light' : 'text-gray-700'} uppercase tracking-wider transition-colors duration-300`}
              >
                Actions
              </th>
            </tr>
          </thead>
          <tbody
            className={`divide-y ${darkMode ? 'divide-gray-700' : 'divide-gray-200'} transition-colors duration-300`}
          >
            {sortedProducts.map((product) => (
              <tr
                key={product.productId}
                className={`hover:${darkMode ? 'bg-gray-800' : 'bg-gray-100'} transition-colors duration-300`}
              >
                <td
                  className={`px-6 py-4 whitespace-nowrap ${darkMode ? 'text-light' : 'text-gray-800'} transition-colors duration-300`}
                >
                  {product.name}
                </td>
                <td
                  className={`px-6 py-4 whitespace-nowrap ${darkMode ? 'text-light' : 'text-gray-800'} transition-colors duration-300`}
                >
                  {product.supplier?.name || 'Unknown'}
                </td>
                <td
                  className={`px-6 py-4 whitespace-nowrap ${darkMode ? 'text-light' : 'text-gray-800'} transition-colors duration-300`}
                >
                  ${product.price.toFixed(2)}
                </td>
                <td
                  className={`px-6 py-4 whitespace-nowrap ${darkMode ? 'text-light' : 'text-gray-800'} transition-colors duration-300`}
                >
                  {product.sku}
                </td>
                <td
                  className={`px-6 py-4 whitespace-nowrap ${darkMode ? 'text-light' : 'text-gray-800'} transition-colors duration-300`}
                >
                  {product.unit}
                </td>
                <td
                  className={`px-6 py-4 whitespace-nowrap ${darkMode ? 'text-light' : 'text-gray-800'} transition-colors duration-300`}
                >
                  {product.discount ? `${(product.discount * 100).toFixed(0)}%` : '-'}
                </td>
                <td
                  className={`px-6 py-4 ${darkMode ? 'text-light' : 'text-gray-800'} transition-colors duration-300`}
                >
                  <div className="max-w-xs truncate">{product.description}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm space-x-2">
                  <button
                    onClick={() => {
                      setEditingProduct(product);
                      setShowForm(true);
                    }}
                    className="inline-flex items-center px-3 py-1 bg-primary text-white rounded hover:bg-accent transition-colors duration-300"
                  >
                    Edit
                  </button>
                  <button
                    onClick={async () => {
                      if (window.confirm('Are you sure you want to delete this product?')) {
                        try {
                          await axios.delete(
                            `${api.baseURL}${api.endpoints.products}/${product.productId}`,
                          );
                          await fetchProducts();
                        } catch (error) {
                          console.error('Error deleting product:', error);
                        }
                      }
                    }}
                    className="inline-flex items-center px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700 transition-colors duration-300"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showForm && (
        <ProductForm
          product={editingProduct}
          suppliers={suppliers}
          onClose={() => setShowForm(false)}
          onSave={fetchProducts}
        />
      )}
    </div>
  );
}
