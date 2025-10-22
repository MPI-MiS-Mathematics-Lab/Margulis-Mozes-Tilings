import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    open: '/UHP.html'
  },
  build: {
    rollupOptions: {
      input: {
        uhp: 'UHP.html',
        disc: 'PoincareDisc.html'
      }
    }
  }
});

