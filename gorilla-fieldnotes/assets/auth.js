(() => {
  const message = document.querySelector('[data-auth-message]');
  const form = document.querySelector('[data-access-form]');
  const input = document.querySelector('#access-key');
  const submit = document.querySelector('[data-submit]');
  const reveal = document.querySelector('[data-reveal-key]');

  const safeNextPath = () => {
    const candidate = new URLSearchParams(window.location.search).get('next') || '/';
    if (!candidate.startsWith('/') || candidate.startsWith('//') || candidate.startsWith('/login') || candidate.includes('\\')) return '/';
    try {
      const url = new URL(candidate, window.location.origin);
      return url.origin === window.location.origin ? `${url.pathname}${url.search}${url.hash}` : '/';
    } catch {
      return '/';
    }
  };

  if (reveal && input) {
    reveal.addEventListener('click', () => {
      const show = input.type === 'password';
      input.type = show ? 'text' : 'password';
      reveal.textContent = show ? 'MASQUER' : 'VOIR';
      reveal.setAttribute('aria-pressed', String(show));
      reveal.setAttribute('aria-label', show ? 'Masquer la clé d’accès' : 'Afficher la clé d’accès');
      input.focus();
    });
  }

  if (form && input && submit) {
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      const key = input.value;
      if (!key.trim()) {
        if (message) message.textContent = 'Saisis la clé d’accès.';
        input.focus();
        return;
      }
      submit.disabled = true;
      submit.textContent = 'VÉRIFICATION…';
      if (message) {
        message.classList.remove('success');
        message.textContent = '';
      }
      try {
        const response = await fetch('/__auth/login', {
          method: 'POST',
          credentials: 'same-origin',
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
          body: JSON.stringify({ key })
        });
        const payload = await response.json().catch(() => ({}));
        if (!response.ok || payload.ok !== true) {
          if (message) message.textContent = payload.message || 'Clé invalide ou accès non configuré. Réessaie ou contacte l’administrateur.';
          input.value = '';
          input.focus();
          return;
        }
        if (message) {
          message.classList.add('success');
          message.textContent = 'Accès confirmé. Ouverture…';
        }
        input.value = '';
        window.location.replace(safeNextPath());
      } catch {
        if (message) message.textContent = 'Le service d’accès est indisponible. Réessaie lorsque le site sera joignable.';
      } finally {
        submit.disabled = false;
        submit.innerHTML = 'OUVRIR L’ARCHIVE <span aria-hidden="true">↗</span>';
      }
    });
  }

  document.querySelectorAll('[data-logout]').forEach((button) => {
    button.addEventListener('click', async () => {
      if (button.disabled) return;
      button.disabled = true;
      const previous = button.textContent;
      button.textContent = 'FERMETURE…';
      try {
        const response = await fetch('/__auth/logout', {
          method: 'POST',
          credentials: 'same-origin',
          headers: { 'Accept': 'application/json' }
        });
        if (!response.ok) throw new Error('Logout failed');
        window.location.replace('/login.html');
      } catch {
        button.disabled = false;
        button.textContent = previous;
        window.alert('Impossible de fermer la session. Vérifie la connexion puis réessaie.');
      }
    });
  });
})();
