import Slider from 'react-slick';
import { useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTheme } from '../context/ThemeContext';

export default function Welcome() {
  const sliderRef = useRef<Slider | null>(null);
  const { darkMode } = useTheme();
  const navigate = useNavigate();

  const sliderSettings = {
    dots: true,
    infinite: true,
    speed: 500,
    slidesToShow: 6,
    slidesToScroll: 1,
    autoplay: true,
    autoplaySpeed: 3000,
    responsive: [
      {
        breakpoint: 1024,
        settings: {
          slidesToShow: 4,
        },
      },
      {
        breakpoint: 768,
        settings: {
          slidesToShow: 3,
        },
      },
      {
        breakpoint: 640,
        settings: {
          slidesToShow: 2,
        },
      },
    ],
  };

  return (
    <div
      className={`relative ${darkMode ? 'bg-dark text-light' : 'bg-white text-gray-800'} transition-colors duration-300`}
    >
      {/* Content */}
      <div className="relative px-4 sm:px-6 lg:px-8 pt-8">
        <div className="relative py-4">
          {/* Hero Image */}
          <div className="w-full max-w-7xl mx-auto">
            <img
              src="/hero.png"
              alt="Smart Cat Products powered by AI"
              className="w-full h-auto rounded-lg"
            />
          </div>

          {/* Text Content */}
          <div className="absolute inset-0 flex items-start pt-16 justify-end max-w-7xl mx-auto px-10 sm:px-12 lg:px-14 mr-[-1rem]">
            <div
              className={`max-w-2xl ${darkMode ? 'bg-dark/60' : 'bg-white/60'} backdrop-blur-sm p-8 rounded-xl shadow-[0_0_25px_rgba(118,184,82,0.5)] transition-colors duration-300`}
            >
              <div
                className={`${darkMode ? 'bg-primary/20' : 'bg-primary/30'} inline-block px-4 py-2 rounded-full mb-4 border border-primary/40`}
              >
                <span className="text-primary-700 dark:text-primary-300 font-semibold">
                  Powered by Advanced AI
                </span>
              </div>
              <h1
                className={`text-5xl font-bold mb-6 leading-tight ${darkMode ? 'text-white' : 'text-gray-800'} transition-colors duration-300`}
              >
                Smart Cat Tech.
                <br />
                Purrsonalized.
              </h1>
              <p
                className={`${darkMode ? 'text-gray-200' : 'text-gray-700'} mb-8 text-lg transition-colors duration-300`}
              >
                OctoCAT Supply brings cutting-edge AI technology to enhance your cat's life. Our
                premium smart products learn from your feline friend's behavior to provide
                personalized experiences, health insights, and next-level entertainment.
              </p>
              <button
                onClick={() => navigate('/products')}
                className="bg-primary hover:bg-accent text-white px-8 py-3 rounded-md font-medium transition-colors cursor-pointer"
              >
                Explore Products
              </button>
            </div>
          </div>
        </div>

        {/* Partner Logos */}
        <div className={`py-2 mt-0 max-w-7xl mx-auto ${darkMode ? 'text-white' : 'text-gray-800'}`}>
          <div className="flex flex-wrap items-center">
            {/* Section Title - Takes 20% width on larger screens */}
            <div className="w-full md:w-1/5 mb-8 md:mb-0">
              <h2 className={`text-3xl font-bold text-left transition-colors duration-300`}>
                Trusted By Cat Lovers Everywhere
              </h2>
            </div>

            {/* Carousel - Takes 80% width on larger screens */}
            <div className="w-full md:w-4/5 px-4">
              {/* SVG Filter Definition */}
              <svg className="hidden">
                <defs>
                  <filter id="green-glow">
                    <feFlood
                      result="flood"
                      floodColor="rgb(118,184,82)"
                      floodOpacity=".3"
                    ></feFlood>
                    <feComposite in="flood" operator="in" in2="SourceGraphic"></feComposite>
                    <feMerge>
                      <feMergeNode></feMergeNode>
                      <feMergeNode in="SourceGraphic"></feMergeNode>
                    </feMerge>
                  </filter>
                </defs>
              </svg>

              <Slider {...sliderSettings} ref={sliderRef} className="opacity-50">
                {/* Logo 1 - Cat Cafe */}
                <div className="flex flex-col items-center justify-center text-center px-4">
                  <div className="flex items-center justify-center transition-all duration-300 group-hover:drop-shadow-[0_0_12px_rgba(118,184,82,0.4)] group-hover:scale-110 mb-2">
                    <svg
                      viewBox="0 0 100 100"
                      className="w-24 h-24 text-gray-500 group-hover:text-primary transition-colors duration-300"
                      style={{ filter: 'url(#green-glow)' }}
                    >
                      <path
                        d="M30 60 C 30 40, 70 40, 70 60"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="3"
                      />
                      <circle cx="35" cy="35" r="7" fill="currentColor" />
                      <circle cx="65" cy="35" r="7" fill="currentColor" />
                      <path d="M40 50 L60 50" stroke="currentColor" strokeWidth="2" />
                      <path
                        d="M45 70 C 45 75, 55 75, 55 70"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  <span className="text-gray-500 text-sm font-medium group-hover:text-primary transition-colors duration-300 w-full text-center">
                    Whiskers Cafe
                  </span>
                </div>

                {/* Logo 2 - Paw Tech */}
                <div className="flex flex-col items-center justify-center text-center px-4">
                  <div className="flex items-center justify-center transition-all duration-300 group-hover:drop-shadow-[0_0_12px_rgba(118,184,82,0.4)] group-hover:scale-110 mb-2">
                    <svg
                      viewBox="0 0 100 100"
                      className="w-24 h-24 text-gray-500 group-hover:text-primary transition-colors duration-300"
                      style={{ filter: 'url(#green-glow)' }}
                    >
                      <circle
                        cx="50"
                        cy="50"
                        r="20"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="3"
                      />
                      <path d="M40 40 L60 40" stroke="currentColor" strokeWidth="2" />
                      <path d="M40 60 L60 60" stroke="currentColor" strokeWidth="2" />
                      <circle
                        cx="30"
                        cy="30"
                        r="10"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                      />
                      <circle
                        cx="70"
                        cy="30"
                        r="10"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                      />
                      <path d="M25 35 L35 25" stroke="currentColor" strokeWidth="2" />
                      <path d="M65 25 L75 35" stroke="currentColor" strokeWidth="2" />
                    </svg>
                  </div>
                  <span className="text-gray-500 text-sm font-medium group-hover:text-primary transition-colors duration-300 w-full text-center">
                    PawTech Solutions
                  </span>
                </div>

                {/* Logo 3 - Feline Innovations */}
                <div className="flex flex-col items-center justify-center text-center px-4">
                  <div className="flex items-center justify-center transition-all duration-300 group-hover:drop-shadow-[0_0_12px_rgba(118,184,82,0.4)] group-hover:scale-110 mb-2">
                    <svg
                      viewBox="0 0 100 100"
                      className="w-24 h-24 text-gray-500 group-hover:text-primary transition-colors duration-300"
                      style={{ filter: 'url(#green-glow)' }}
                    >
                      <path
                        d="M25 50 Q 50 20, 75 50"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="3"
                      />
                      <path
                        d="M25 70 Q 50 40, 75 70"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="3"
                      />
                      <circle cx="30" cy="30" r="5" fill="currentColor" />
                      <circle cx="70" cy="30" r="5" fill="currentColor" />
                    </svg>
                  </div>
                  <span className="text-gray-500 text-sm font-medium group-hover:text-primary transition-colors duration-300 w-full text-center">
                    Feline Innovations
                  </span>
                </div>

                {/* Logo 4 - Cat Health AI */}
                <div className="flex flex-col items-center justify-center text-center px-4">
                  <div className="flex items-center justify-center transition-all duration-300 group-hover:drop-shadow-[0_0_12px_rgba(118,184,82,0.4)] group-hover:scale-110 mb-2">
                    <svg
                      viewBox="0 0 100 100"
                      className="w-24 h-24 text-gray-500 group-hover:text-primary transition-colors duration-300"
                      style={{ filter: 'url(#green-glow)' }}
                    >
                      <path
                        d="M30 30 L70 30 L70 70 L30 70 Z"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="3"
                      />
                      <path d="M50 20 L50 80" stroke="currentColor" strokeWidth="2" />
                      <path d="M20 50 L80 50" stroke="currentColor" strokeWidth="2" />
                      <circle
                        cx="50"
                        cy="50"
                        r="10"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                      />
                      <path d="M60 40 L65 35" stroke="currentColor" strokeWidth="2" />
                    </svg>
                  </div>
                  <span className="text-gray-500 text-sm font-medium group-hover:text-primary transition-colors duration-300 w-full text-center">
                    CatHealth AI
                  </span>
                </div>

                {/* Logo 5 - Purr Tech */}
                <div className="flex flex-col items-center justify-center text-center px-4">
                  <div className="flex items-center justify-center transition-all duration-300 group-hover:drop-shadow-[0_0_12px_rgba(118,184,82,0.4)] group-hover:scale-110 mb-2">
                    <svg
                      viewBox="0 0 100 100"
                      className="w-24 h-24 text-gray-500 group-hover:text-primary transition-colors duration-300"
                      style={{ filter: 'url(#green-glow)' }}
                    >
                      <circle
                        cx="50"
                        cy="40"
                        r="15"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="3"
                      />
                      <path d="M35 55 L25 80" stroke="currentColor" strokeWidth="3" />
                      <path d="M65 55 L75 80" stroke="currentColor" strokeWidth="3" />
                      <path d="M43 35 L57 35" stroke="currentColor" strokeWidth="2" />
                      <circle cx="40" cy="30" r="3" fill="currentColor" />
                      <circle cx="60" cy="30" r="3" fill="currentColor" />
                      <path
                        d="M45 45 C 50 50, 55 50, 60 45"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  <span className="text-gray-500 text-sm font-medium group-hover:text-primary transition-colors duration-300 w-full text-center">
                    PurrTech Innovations
                  </span>
                </div>

                {/* Logo 6 - Whisker Data */}
                <div className="flex flex-col items-center justify-center text-center px-4">
                  <div className="flex items-center justify-center transition-all duration-300 group-hover:drop-shadow-[0_0_12px_rgba(118,184,82,0.4)] group-hover:scale-110 mb-2">
                    <svg
                      viewBox="0 0 100 100"
                      className="w-24 h-24 text-gray-500 group-hover:text-primary transition-colors duration-300"
                      style={{ filter: 'url(#green-glow)' }}
                    >
                      <path
                        d="M30 70 Q 50 40, 70 70"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="3"
                      />
                      <path d="M20 60 L80 60" stroke="currentColor" strokeWidth="2" />
                      <path d="M20 50 L80 50" stroke="currentColor" strokeWidth="2" />
                      <path d="M20 40 L80 40" stroke="currentColor" strokeWidth="2" />
                      <circle cx="35" cy="30" r="5" fill="currentColor" />
                      <circle cx="65" cy="30" r="5" fill="currentColor" />
                    </svg>
                  </div>
                  <span className="text-gray-500 text-sm font-medium group-hover:text-primary transition-colors duration-300 w-full text-center">
                    WhiskerWare Systems
                  </span>
                </div>
              </Slider>
            </div>
          </div>
        </div>

        {/* Product Categories */}
        <div className="py-16">
          <h2
            className={`text-3xl font-bold ${darkMode ? 'text-white' : 'text-gray-800'} text-center mb-12 transition-colors duration-300`}
          >
            Smart Solutions for Modern Cats
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-7xl mx-auto">
            <div
              className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-lg p-6 shadow-lg hover:shadow-[0_0_15px_rgba(118,184,82,0.3)] transition-all duration-300`}
            >
              <div className="text-primary text-4xl mb-4">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="h-12 w-12"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
              </div>
              <h3
                className={`text-xl font-bold ${darkMode ? 'text-white' : 'text-gray-800'} mb-2 transition-colors duration-300`}
              >
                Smart Monitoring
              </h3>
              <p
                className={`${darkMode ? 'text-gray-300' : 'text-gray-600'} transition-colors duration-300`}
              >
                AI-powered devices that track your cat's health, activity, and behavior patterns to
                provide valuable insights.
              </p>
            </div>
            <div
              className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-lg p-6 shadow-lg hover:shadow-[0_0_15px_rgba(118,184,82,0.3)] transition-all duration-300`}
            >
              <div className="text-primary text-4xl mb-4">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="h-12 w-12"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
                  />
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
              <h3
                className={`text-xl font-bold ${darkMode ? 'text-white' : 'text-gray-800'} mb-2 transition-colors duration-300`}
              >
                Interactive Entertainment
              </h3>
              <p
                className={`${darkMode ? 'text-gray-300' : 'text-gray-600'} transition-colors duration-300`}
              >
                Engaging toys and systems that adapt to your cat's play style and preferences for
                maximum enjoyment.
              </p>
            </div>
            <div
              className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-lg p-6 shadow-lg hover:shadow-[0_0_15px_rgba(118,184,82,0.3)] transition-all duration-300`}
            >
              <div className="text-primary text-4xl mb-4">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="h-12 w-12"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                  />
                </svg>
              </div>
              <h3
                className={`text-xl font-bold ${darkMode ? 'text-white' : 'text-gray-800'} mb-2 transition-colors duration-300`}
              >
                Comfort & Wellness
              </h3>
              <p
                className={`${darkMode ? 'text-gray-300' : 'text-gray-600'} transition-colors duration-300`}
              >
                Smart beds, feeding solutions, and grooming tools designed to enhance your cat's
                health and comfort.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
