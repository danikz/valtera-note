import './app.css';
import { mount } from 'svelte';
import App from './App.svelte';

const appElement = document.getElementById('app');
if (!appElement) {
  throw new Error('Root app element #app not found');
}

const app = mount(App, {
  target: appElement,
});

export default app;
