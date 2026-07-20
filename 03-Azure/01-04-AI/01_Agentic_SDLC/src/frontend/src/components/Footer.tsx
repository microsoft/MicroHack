import React from 'react';
import { useTheme } from '../context/ThemeContext';

const Footer: React.FC = () => {
  const { darkMode } = useTheme();

  return (
    <footer
      className={`${darkMode ? 'bg-gray-900 text-gray-300' : 'bg-gray-200 text-gray-700'} py-8 transition-colors duration-300`}
    >
      <div className="container mx-auto px-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          {/* About Section */}
          <div>
            <h2 className="font-bold text-xl mb-4 text-primary">About</h2>
            <p className="text-sm">
              OctoCAT Supply is the leading provider of AI-powered smart products for your feline
              companions. Our innovative technology enhances your cat's wellbeing through
              intelligent monitoring, interactive entertainment, and personalized comfort solutions.
            </p>
          </div>

          {/* Account Section */}
          <div>
            <h2 className="font-bold text-xl mb-4 text-primary">Account</h2>
            <ul className="space-y-2">
              <li>
                <a href="#" className="hover:text-primary">
                  My Cart
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Checkout
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Shopping Details
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Order
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Help Center
                </a>
              </li>
            </ul>
          </div>

          {/* Helpful Links Section */}
          <div>
            <h2 className="font-bold text-xl mb-4 text-primary">Helpful Links</h2>
            <ul className="space-y-2">
              <li>
                <a href="#" className="hover:text-primary">
                  Services
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Supports
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Feedback
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Terms & Conditions
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Privacy Policy
                </a>
              </li>
            </ul>
          </div>

          {/* Social Media Section */}
          <div>
            <h2 className="font-bold text-xl mb-4 text-primary">Social Media</h2>
            <ul className="space-y-2">
              <li>
                <a href="#" className="hover:text-primary">
                  Twitter
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Facebook
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Youtube
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Linkedin
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-primary">
                  Instagram
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div
          className={`mt-8 pt-8 ${darkMode ? 'border-gray-700' : 'border-gray-300'} border-t text-center text-sm transition-colors duration-300`}
        >
          <p>Copyright © 2025 OctoCAT Supply. All Rights Reserved</p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
