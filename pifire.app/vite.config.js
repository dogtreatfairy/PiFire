import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

// Use an environment variable for the backend address, defaulting to localhost:8000
const backendAddress = process.env.BACKEND_ADDRESS || 'http://localhost:8000';

export default defineConfig({
    plugins: [sveltekit()],
    server: {
		hmr: true,
        proxy: {
            '/api': {
                target: backendAddress, // Dynamically use the backend address
                changeOrigin: true
            }
        }
    }
});