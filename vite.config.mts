import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    open: '/viewer.html'
  },
  build: {
    rollupOptions: {
      input: {
        viewer: 'viewer.html'
      }
    }
  }
});

