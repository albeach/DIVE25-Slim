FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies with clean npm cache
RUN npm cache clean --force && \
    npm install

# Copy the rest of the application
COPY . .

# Install additional required packages
RUN npm install @swc/helpers react-dom axios

# Build the application
RUN npm run build

# Start the application
CMD ["npm", "run", "dev"]
