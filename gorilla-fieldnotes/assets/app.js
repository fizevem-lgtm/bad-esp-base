(() => {
  const menuButton = document.querySelector('[data-menu-button]');
  const nav = document.querySelector('[data-main-nav]');
  if (menuButton && nav) {
    menuButton.addEventListener('click', () => {
      const opened = nav.classList.toggle('open');
      menuButton.setAttribute('aria-expanded', String(opened));
      menuButton.textContent = opened ? 'CLOSE −' : 'MENU +';
    });
    nav.addEventListener('click', (event) => {
      if (event.target.closest('a')) {
        nav.classList.remove('open');
        menuButton.setAttribute('aria-expanded', 'false');
        menuButton.textContent = 'MENU +';
      }
    });
  }

  const directory = document.querySelector('[data-directory]');
  if (!directory) return;
  const search = document.querySelector('[data-search]');
  const rows = [...directory.querySelectorAll('[data-resource]')];
  const groups = [...directory.querySelectorAll('[data-group]')];
  const chips = [...document.querySelectorAll('[data-filter]')];
  const resultCount = document.querySelector('[data-result-count]');
  const empty = document.querySelector('[data-empty]');
  const clear = document.querySelector('[data-clear]');
  const copyVisible = document.querySelector('[data-copy-visible]');
  const compact = document.querySelector('[data-compact]');
  let category = 'all';

  const applyFilters = () => {
    const query = (search?.value || '').trim().toLocaleLowerCase('fr-CA');
    let visible = 0;
    rows.forEach(row => {
      const rowCategory = row.dataset.category || '';
      const haystack = (row.dataset.search || row.textContent).toLocaleLowerCase('fr-CA');
      const show = (category === 'all' || category === rowCategory) && (!query || haystack.includes(query));
      row.hidden = !show;
      if (show) visible++;
    });
    groups.forEach(group => {
      group.hidden = !group.querySelector('[data-resource]:not([hidden])');
    });
    if (resultCount) resultCount.textContent = String(visible).padStart(2, '0');
    if (empty) empty.classList.toggle('visible', visible === 0);
    if (copyVisible) copyVisible.disabled = visible === 0;
  };

  search?.addEventListener('input', applyFilters);
  chips.forEach(chip => chip.addEventListener('click', () => {
    category = chip.dataset.filter || 'all';
    chips.forEach(item => item.setAttribute('aria-pressed', String(item === chip)));
    applyFilters();
  }));
  clear?.addEventListener('click', () => {
    if (search) search.value = '';
    category = 'all';
    chips.forEach(chip => chip.setAttribute('aria-pressed', String(chip.dataset.filter === 'all')));
    applyFilters();
    search?.focus();
  });
  compact?.addEventListener('click', () => {
    const enabled = document.body.classList.toggle('is-compact');
    compact.setAttribute('aria-pressed', String(enabled));
    compact.textContent = enabled ? 'COMFORT VIEW +' : 'COMPACT VIEW −';
  });

  const copyText = async (text, button) => {
    const original = button.textContent;
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = 'COPIED ✓';
    } catch {
      const area = document.createElement('textarea');
      area.value = text;
      area.setAttribute('readonly', '');
      area.style.position = 'fixed';
      area.style.opacity = '0';
      document.body.append(area);
      area.select();
      const ok = document.execCommand('copy');
      area.remove();
      button.textContent = ok ? 'COPIED ✓' : 'COPY FAILED';
    }
    window.setTimeout(() => { button.textContent = original; }, 1500);
  };
  directory.addEventListener('click', event => {
    const button = event.target.closest('[data-copy-url]');
    if (!button) return;
    const row = button.closest('[data-resource]');
    const link = row?.querySelector('[data-official-link]');
    if (link) copyText(link.href, button);
  });
  copyVisible?.addEventListener('click', () => {
    const text = rows.filter(row => !row.hidden).map(row => {
      const link = row.querySelector('[data-official-link]');
      return link ? `${link.textContent.trim()} — ${link.href}` : '';
    }).filter(Boolean).join('\n');
    if (text) copyText(text, copyVisible);
  });
  applyFilters();
})();
