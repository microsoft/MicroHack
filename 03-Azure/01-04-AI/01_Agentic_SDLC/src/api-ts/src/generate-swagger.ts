import swaggerJsdoc from 'swagger-jsdoc';
import { writeFileSync } from 'fs';
import { resolve } from 'path';

const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Express API with Swagger',
      version: '1.0.0',
      description: 'REST API documentation using Swagger/OpenAPI',
    },
    servers: [
      {
        url: 'http://localhost:3000',
        description: 'Development server',
      },
    ],
  },
  apis: ['./src/models/*.ts', './src/routes/*.ts'],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);
const outputPath = resolve(__dirname, '..', 'api-swagger.json');

writeFileSync(outputPath, JSON.stringify(swaggerSpec, null, 4) + '\n');
console.log(`Swagger spec written to ${outputPath}`);
