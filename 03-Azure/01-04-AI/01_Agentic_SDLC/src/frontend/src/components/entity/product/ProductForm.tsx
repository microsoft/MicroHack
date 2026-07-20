import { useState } from 'react';
import axios from 'axios';
import { api } from '../../../api/config';
import { useTheme } from '../../../context/ThemeContext';

interface Supplier {
  supplierId: number;
  name: string;
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
  discount?: number;
}

interface ProductFormProps {
  product?: Product;
  suppliers: Supplier[];
  onClose: () => void;
  onSave: () => void;
}

export default function ProductForm({ product, suppliers, onClose, onSave }: ProductFormProps) {
  const { darkMode } = useTheme();

  const [formData, setFormData] = useState<Partial<Product>>(
    product || {
      name: '',
      description: '',
      price: 0,
      sku: '',
      unit: '',
      supplierId: suppliers[0]?.supplierId || 0,
      imgName: '',
    },
  );

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (product) {
        await axios.put(`${api.baseURL}${api.endpoints.products}/${product.productId}`, formData);
      } else {
        await axios.post(`${api.baseURL}${api.endpoints.products}`, formData);
      }
      if (typeof onSave === 'function') {
        onSave();
      }
      if (typeof onClose === 'function') {
        onClose();
      }
    } catch (error) {
      console.error('Error saving product:', error);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div
        className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-lg p-6 w-full max-w-md shadow-xl transition-colors duration-300`}
      >
        <h2
          className={`text-2xl font-bold ${darkMode ? 'text-light' : 'text-gray-800'} mb-4 transition-colors duration-300`}
        >
          {product ? 'Edit Product' : 'Add New Product'}
        </h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label
              className={`block ${darkMode ? 'text-light' : 'text-gray-700'} mb-1 transition-colors duration-300`}
            >
              Name
            </label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              className={`w-full px-3 py-2 ${darkMode ? 'bg-gray-700 text-light' : 'bg-gray-100 text-gray-800'} rounded transition-colors duration-300`}
              required
            />
          </div>
          <div>
            <label
              className={`block ${darkMode ? 'text-light' : 'text-gray-700'} mb-1 transition-colors duration-300`}
            >
              Description
            </label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className={`w-full px-3 py-2 ${darkMode ? 'bg-gray-700 text-light' : 'bg-gray-100 text-gray-800'} rounded transition-colors duration-300`}
              required
            />
          </div>
          <div>
            <label
              className={`block ${darkMode ? 'text-light' : 'text-gray-700'} mb-1 transition-colors duration-300`}
            >
              Price
            </label>
            <input
              type="number"
              value={formData.price}
              onChange={(e) => setFormData({ ...formData, price: parseFloat(e.target.value) })}
              className={`w-full px-3 py-2 ${darkMode ? 'bg-gray-700 text-light' : 'bg-gray-100 text-gray-800'} rounded transition-colors duration-300`}
              required
              min="0"
              step="0.01"
            />
          </div>
          <div>
            <label
              className={`block ${darkMode ? 'text-light' : 'text-gray-700'} mb-1 transition-colors duration-300`}
            >
              SKU
            </label>
            <input
              type="text"
              value={formData.sku}
              onChange={(e) => setFormData({ ...formData, sku: e.target.value })}
              className={`w-full px-3 py-2 ${darkMode ? 'bg-gray-700 text-light' : 'bg-gray-100 text-gray-800'} rounded transition-colors duration-300`}
              required
            />
          </div>
          <div>
            <label
              className={`block ${darkMode ? 'text-light' : 'text-gray-700'} mb-1 transition-colors duration-300`}
            >
              Unit
            </label>
            <input
              type="text"
              value={formData.unit}
              onChange={(e) => setFormData({ ...formData, unit: e.target.value })}
              className={`w-full px-3 py-2 ${darkMode ? 'bg-gray-700 text-light' : 'bg-gray-100 text-gray-800'} rounded transition-colors duration-300`}
              required
            />
          </div>
          <div>
            <label
              className={`block ${darkMode ? 'text-light' : 'text-gray-700'} mb-1 transition-colors duration-300`}
            >
              Image Name
            </label>
            <input
              type="text"
              value={formData.imgName}
              onChange={(e) => setFormData({ ...formData, imgName: e.target.value })}
              className={`w-full px-3 py-2 ${darkMode ? 'bg-gray-700 text-light' : 'bg-gray-100 text-gray-800'} rounded transition-colors duration-300`}
              required
            />
          </div>
          <div>
            <label
              className={`block ${darkMode ? 'text-light' : 'text-gray-700'} mb-1 transition-colors duration-300`}
            >
              Supplier
            </label>
            <select
              value={formData.supplierId}
              onChange={(e) => setFormData({ ...formData, supplierId: parseInt(e.target.value) })}
              className={`w-full px-3 py-2 ${darkMode ? 'bg-gray-700 text-light' : 'bg-gray-100 text-gray-800'} rounded transition-colors duration-300`}
              required
            >
              {suppliers.map((supplier) => (
                <option key={supplier.supplierId} value={supplier.supplierId}>
                  {supplier.name}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label
              className={`block ${darkMode ? 'text-light' : 'text-gray-700'} mb-1 transition-colors duration-300`}
            >
              Discount (%)
            </label>
            <input
              type="number"
              value={formData.discount !== undefined ? formData.discount * 100 : ''}
              onChange={(e) => {
                const value = e.target.value === '' ? undefined : parseFloat(e.target.value) / 100;
                setFormData({ ...formData, discount: value });
              }}
              placeholder="Enter discount percentage (e.g. 25 for 25%)"
              className={`w-full px-3 py-2 ${darkMode ? 'bg-gray-700 text-light' : 'bg-gray-100 text-gray-800'} rounded transition-colors duration-300`}
              min="0"
              max="100"
              step="1"
            />
            <p className={`text-xs mt-1 ${darkMode ? 'text-gray-400' : 'text-gray-500'}`}>
              Leave empty for no discount
            </p>
          </div>
          <div className="flex justify-end space-x-2">
            <button
              type="button"
              onClick={onClose}
              className={`px-4 py-2 ${darkMode ? 'bg-gray-600' : 'bg-gray-300'} ${darkMode ? 'text-white' : 'text-gray-800'} rounded hover:${darkMode ? 'bg-gray-500' : 'bg-gray-400'} transition-colors duration-300`}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-2 bg-primary text-white rounded hover:bg-accent transition-colors duration-300"
            >
              {product ? 'Update' : 'Create'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
