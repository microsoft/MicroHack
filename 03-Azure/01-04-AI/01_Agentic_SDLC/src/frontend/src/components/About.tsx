import { useTheme } from '../context/ThemeContext';

const About = () => {
  const { darkMode } = useTheme();

  return (
    <div
      className={`min-h-screen flex flex-col items-center justify-center ${darkMode ? 'bg-dark' : 'bg-gray-100'} p-4 transition-colors duration-300`}
    >
      <div
        className={`max-w-4xl w-full ${darkMode ? 'bg-gray-800 text-gray-300' : 'bg-white text-gray-700'} rounded-lg shadow-lg p-8 border ${darkMode ? 'border-primary/20' : 'border-gray-200'} transition-colors duration-300`}
      >
        <h1
          className={`text-4xl font-bold mb-8 ${darkMode ? 'text-white' : 'text-gray-800'} transition-colors duration-300`}
        >
          About OctoCAT Supply
        </h1>
        <div className="space-y-6">
          <p>
            Welcome to OctoCAT Supply, your premier destination for AI-powered smart products
            designed specifically for your feline companions. Our cutting-edge cat tech innovations
            bring together the latest in artificial intelligence, sensor technology, and
            pet-friendly design to enhance the bond between you and your cat.
          </p>
          <h2 className="text-2xl font-bold text-primary">Our Meow-ssion</h2>
          <p>
            To revolutionize the way cats and humans interact through thoughtfully designed,
            AI-enhanced products that improve feline happiness, health monitoring, and enrichment
            while delighting their human companions with valuable insights.
          </p>
          <h2 className="text-2xl font-bold text-primary">Our Purr-pose</h2>
          <p>
            At OctoCAT Supply, we believe that cats deserve the same technological innovations that
            humans enjoy. Our team of feline behavior specialists, engineers, and AI experts work
            together to create products that understand, respond to, and improve your cat's daily
            life.
          </p>
          <h2 className="text-2xl font-bold text-primary">Key Features of Our Products</h2>
          <ul className="list-disc list-inside space-y-2">
            <li>AI-powered behavior analysis and personalization</li>
            <li>Real-time health monitoring and wellness alerts</li>
            <li>Multi-cat household compatibility</li>
            <li>Smartphone integration with detailed analytics</li>
            <li>Energy-efficient and eco-friendly materials</li>
            <li>Sleek, modern designs that complement your home</li>
          </ul>
          <div
            className={`mt-8 p-4 ${darkMode ? 'bg-gray-700' : 'bg-gray-200'} rounded-lg transition-colors duration-300`}
          >
            <p className="italic">
              "Our cats tested every product in our catalog extensively. Only the ones they couldn't
              stop using made it to production." — Felix Whiskerton, Founder
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default About;
