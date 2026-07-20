import { Supplier } from './models/supplier';
import { Product } from './models/product';
import { Headquarters } from './models/headquarters';
import { Branch } from './models/branch';
import { Order } from './models/order';
import { OrderDetail } from './models/orderDetail';
import { Delivery } from './models/delivery';
import { OrderDetailDelivery } from './models/orderDetailDelivery';

// Suppliers
export const suppliers: Supplier[] = [
  {
    supplierId: 1,
    name: 'PurrTech Innovations',
    description: 'Leading supplier of premium smart cat technology',
    contactPerson: 'Felix Whiskerton',
    email: 'felix@purrtech.co',
    phone: '555-0101',
    active: true,
    verified: true,
  },
  {
    supplierId: 2,
    name: 'WhiskerWare Systems',
    description: 'Advanced feline-focused smart product supplier',
    contactPerson: 'Tabitha Pawson',
    email: 'tabitha@whiskerware.com',
    phone: '555-0102',
    active: true,
    verified: false,
  },
  {
    supplierId: 3,
    name: 'CatNip Creations',
    description: 'Supplier of eco-friendly cat toys and accessories',
    contactPerson: 'Nina Nibbles',
    email: 'nina@catnip.com',
    phone: '555-0103',
    active: false,
    verified: false
  },
];

// Products
export const products: Product[] = [
  {
    productId: 1,
    supplierId: 3,
    name: 'SmartFeeder One',
    description:
      "This AI-powered feeder learns your cat's snack schedule based on nap cycles and mealtime habits. It detects overeating, undernapping, and auto-updates a Feline Health Repo.",
    price: 129.99,
    sku: 'CAT-FEED-001',
    unit: 'piece',
    imgName: 'feeder.png',
    discount: 0.25,
  },
  {
    productId: 2,
    supplierId: 3,
    name: 'AutoClean Litter Dome',
    description:
      "A self-cleaning litter box that detects patterns in your cat's... commits. Sends you a health report and Slack alert if things look off.",
    price: 199.99,
    sku: 'CAT-LITTER-001',
    unit: 'piece',
    imgName: 'litter-box.png',
    discount: 0.25,
  },
  {
    productId: 3,
    supplierId: 2,
    name: 'CatFlix Entertainment Portal',
    description:
      'On-demand laser shows, motion videos, and bird-watching streams - customized per cat using AI interest tracking. Think Netflix, but for felines.',
    price: 89.99,
    sku: 'CAT-FLIX-001',
    unit: 'piece',
    imgName: 'catflix.png',
  },
  {
    productId: 4,
    supplierId: 2,
    name: 'PawTrack Smart Collar',
    description:
      'GPS and activity tracker with AI-powered mood detection based on tail position, purring frequency, and movement patterns. Syncs with your phone for walk stats and zoomie alerts.',
    price: 79.99,
    sku: 'CAT-COLLAR-001',
    unit: 'piece',
    imgName: 'smart-collar.png',
  },
  {
    productId: 5,
    supplierId: 1,
    name: 'SleepNest ThermoPod',
    description:
      "A smart bed that adjusts its temperature, lighting, and white noise based on your cat's REM cycles. Auto-generates nap metrics in JSON.",
    price: 149.99,
    sku: 'CAT-BED-001',
    unit: 'piece',
    imgName: 'sleep-nest.png',
  },
  {
    productId: 6,
    supplierId: 1,
    name: 'ClawMate Auto Groomer',
    description:
      'Your cat brushes itself. This AI station detects which areas need grooming, dispenses treats for patience, and logs grooming history to your pet portal.',
    price: 119.99,
    sku: 'CAT-GROOM-001',
    unit: 'piece',
    imgName: 'auto-groomer.png',
  },
  {
    productId: 7,
    supplierId: 3,
    name: 'Smart Fountain Flow+',
    description:
      'This water fountain adjusts flow patterns based on time of day, cat hydration levels, and even playfulness. Uses facial recognition to distinguish multiple cats.',
    price: 69.99,
    sku: 'CAT-FOUNTAIN-001',
    unit: 'piece',
    imgName: 'smart-fountain.png',
    discount: 0.25,
  },
  {
    productId: 8,
    supplierId: 2,
    name: 'ScratchPad Pro',
    description:
      'More than a scratcher - this one detects scratching habits, gamifies it with leaderboard stats for multi-cat homes, and awards digital badges.',
    price: 59.99,
    sku: 'CAT-SCRATCH-001',
    unit: 'piece',
    imgName: 'scratch-pad.png',
  },
  {
    productId: 9,
    supplierId: 2,
    name: 'ChirpCam Window Mount',
    description:
      "Motion-activated smart cam that records wildlife outside the window and sends curated 'Birdflix' highlights to your cat's personal feed.",
    price: 99.99,
    sku: 'CAT-CAM-001',
    unit: 'piece',
    imgName: 'chirp-cam.png',
  },
  {
    productId: 10,
    supplierId: 3,
    name: 'SnackVault Puzzle Dispenser',
    description:
      "Treat puzzle toy that evolves in difficulty with your cat's cleverness. AI engine auto-adjusts pathways and provides tips to the human if the cat cheats.",
    price: 49.99,
    sku: 'CAT-SNACK-001',
    unit: 'piece',
    imgName: 'snack-vault.png',
    discount: 0.25,
  },
  {
    productId: 11,
    supplierId: 1,
    name: 'DoorDash Pet Portal',
    description:
      'Smart cat door with facial recognition and time-based access. Prevents midnight squirrel parties and tracks in/out commits to your dashboard.',
    price: 159.99,
    sku: 'CAT-DOOR-001',
    unit: 'piece',
    imgName: 'door-dash.png',
  },
  {
    productId: 12,
    supplierId: 2,
    name: 'ZoomieTracker AI Mat',
    description:
      'A motion-sensing mat that detects zoomies, spins up chase lights, and logs agility bursts to a weekly health report. Yes, it graphs zoomies per hour.',
    price: 79.99,
    sku: 'CAT-TRACKER-001',
    unit: 'piece',
    imgName: 'tracker-mat.png',
  },
];

// Headquarters
export const headquarters: Headquarters[] = [
  {
    headquartersId: 1,
    name: 'CatTech Global HQ',
    description: 'Feline tech innovations headquarters',
    address: '123 Whisker Lane, Purrington District',
    contactPerson: 'Catherine Purrston',
    email: 'catherine@octocat.com',
    phone: '555-0001',
  },
];

// Branches
export const branches: Branch[] = [
  {
    branchId: 1,
    headquartersId: 1,
    name: 'Meowtown Branch',
    description: 'Main downtown cat tech showroom',
    address: '456 Purrfect Plaza',
    contactPerson: 'Chloe Whiskers',
    email: 'cwhiskers@octocat.com',
    phone: '555-0201',
  },
  {
    branchId: 2,
    headquartersId: 1,
    name: 'Tabby Terrace Branch',
    description: 'Western district cat tech hub',
    address: '789 Feline Avenue',
    contactPerson: 'Tom Pouncer',
    email: 'tpouncer@octocat.com',
    phone: '555-0202',
  },
];

// Orders
export const orders: Order[] = [
  {
    orderId: 1,
    branchId: 1,
    orderDate: new Date().toISOString(),
    name: 'Q2 Feline Tech Refresh',
    description: 'Quarterly smart cat tech product refresh',
    status: 'pending',
  },
  {
    orderId: 2,
    branchId: 2,
    orderDate: new Date().toISOString(),
    name: 'Cat Enrichment Bundle',
    description: 'Monthly cat entertainment systems restock',
    status: 'processing',
  },
];

// Order Details
export const orderDetails: OrderDetail[] = [
  {
    orderDetailId: 1,
    orderId: 1,
    productId: 2,
    quantity: 5,
    unitPrice: 199.99,
    notes: 'AutoClean Litter Domes for new cat café locations',
  },
  {
    orderDetailId: 2,
    orderId: 1,
    productId: 3,
    quantity: 5,
    unitPrice: 89.99,
    notes: 'CatFlix Entertainment Portals for waiting areas',
  },
  {
    orderDetailId: 3,
    orderId: 2,
    productId: 4,
    quantity: 20,
    unitPrice: 79.99,
    notes: 'PawTrack Smart Collars for adoption events',
  },
];

// Deliveries
export const deliveries: Delivery[] = [
  {
    deliveryId: 1,
    supplierId: 1,
    deliveryDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // 7 days from now
    name: 'PurrTech Smart Home Bundle',
    description: 'Premium cat tech products delivery for smart cat homes',
    status: 'pending',
  },
  {
    deliveryId: 2,
    supplierId: 2,
    deliveryDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(), // 2 days from now
    name: 'WhiskerWare Entertainment Package',
    description: 'Entertainment and tracking systems for feline companions',
    status: 'in-transit',
  },
];

// Order Detail Deliveries
export const orderDetailDeliveries: OrderDetailDelivery[] = [
  {
    orderDetailDeliveryId: 1,
    orderDetailId: 1,
    deliveryId: 1,
    quantity: 5,
    notes: 'Delivery batch',
  },
  {
    orderDetailDeliveryId: 2,
    orderDetailId: 2,
    deliveryId: 1,
    quantity: 5,
    notes: 'Delivery batch',
  },
  {
    orderDetailDeliveryId: 3,
    orderDetailId: 3,
    deliveryId: 2,
    quantity: 20,
    notes: 'Delivery',
  },
];
