FROM node:18-alpine

WORKDIR /app

# Copy package files first
COPY package*.json ./

# Install only production dependencies
RUN npm install --production --ignore-scripts

# Copy the pre-built application
COPY dist/ ./dist/
COPY cli.js ./
COPY index.d.ts ./
COPY config.d.ts ./
COPY index.js ./

# Make CLI executable
RUN chmod +x cli.js

# Expose port
EXPOSE 8080

# Set environment variables
ENV PORT=8080
ENV NODE_ENV=production

# Start the server
CMD ["node", "cli.js", "--port", "8080", "--host", "0.0.0.0"]
