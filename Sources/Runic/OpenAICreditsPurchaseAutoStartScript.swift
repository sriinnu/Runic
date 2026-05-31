enum OpenAICreditsPurchaseAutoStartScript {
    static let source = """
    (() => {
      if (window.__runicAutoBuyCreditsStarted) return 'already';
      const log = (...args) => {
        try {
          window.webkit?.messageHandlers?.runicLog?.postMessage(args);
        } catch {}
      };
      const buttonSelector = 'button, a, [role="button"], input[type="button"], input[type="submit"]';
      const isVisible = (el) => {
        if (!el || !el.getBoundingClientRect) return false;
        const rect = el.getBoundingClientRect();
        if (rect.width < 2 || rect.height < 2) return false;
        const style = window.getComputedStyle ? window.getComputedStyle(el) : null;
        if (style) {
          if (style.display === 'none' || style.visibility === 'hidden') return false;
          if (parseFloat(style.opacity || '1') === 0) return false;
        }
        return true;
      };
      const textOf = el => {
        const raw = el && (el.innerText || el.textContent) ? String(el.innerText || el.textContent) : '';
        return raw.trim();
      };
      const matches = text => {
        const lower = String(text || '').toLowerCase();
        if (!lower.includes('credit')) return false;
        return (
          lower.includes('buy') ||
          lower.includes('add') ||
          lower.includes('purchase') ||
          lower.includes('top up') ||
          lower.includes('top-up')
        );
      };
      const matchesAddMore = text => {
        const lower = String(text || '').toLowerCase();
        return lower.includes('add more');
      };
      const labelFor = el => {
        if (!el) return '';
        return textOf(el) || el.getAttribute('aria-label') || el.getAttribute('title') || el.value || '';
      };
      const summarize = el => {
        if (!el) return null;
        return {
          tag: el.tagName,
          type: el.getAttribute('type'),
          role: el.getAttribute('role'),
          label: labelFor(el),
          aria: el.getAttribute('aria-label'),
          disabled: isDisabled(el),
          href: el.getAttribute('href'),
          testId: el.getAttribute('data-testid'),
          className: (el.className && String(el.className).slice(0, 120)) || ''
        };
      };
      const collectButtons = () => {
        const results = new Set();
        const addAll = (root) => {
          if (!root || !root.querySelectorAll) return;
          root.querySelectorAll(buttonSelector).forEach(el => results.add(el));
        };
        addAll(document);
        document.querySelectorAll('*').forEach(el => {
          if (el.shadowRoot) addAll(el.shadowRoot);
        });
        document.querySelectorAll('iframe').forEach(frame => {
          try {
            const doc = frame.contentDocument;
            if (!doc) return;
            addAll(doc);
            doc.querySelectorAll('*').forEach(el => {
              if (el.shadowRoot) addAll(el.shadowRoot);
            });
          } catch {}
        });
        return Array.from(results);
      };
      const findDialogNextButton = () => {
        const dialog = document.querySelector('[role=\"dialog\"], dialog, [aria-modal=\"true\"]');
        if (!dialog) return null;
        const buttons = Array.from(dialog.querySelectorAll(buttonSelector));
        const labeled = buttons.filter(btn => labelFor(btn).toLowerCase().startsWith('next'));
        const visible = labeled.find(isVisible);
        return visible || labeled[0] || null;
      };
      const clickButton = (el) => {
        if (!el) return false;
        try {
          el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
        } catch {
          try {
            el.click();
          } catch {
            return false;
          }
        }
        return true;
      };
      const triggerPointerClick = (el) => {
        if (!el) return false;
        const rect = el.getBoundingClientRect ? el.getBoundingClientRect() : null;
        if (!rect) return false;
        const x = rect.left + rect.width / 2;
        const y = rect.top + rect.height / 2;
        const events = ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'];
        for (const type of events) {
          try {
            el.dispatchEvent(new MouseEvent(type, {
              bubbles: true,
              cancelable: true,
              view: window,
              clientX: x,
              clientY: y
            }));
          } catch {
            return false;
          }
        }
        return true;
      };
      const pickLikelyButton = (buttons) => {
        if (!buttons || buttons.length === 0) return null;
        const labeled = buttons.find(btn => {
          const label = labelFor(btn);
          if (matches(label) || matchesAddMore(label)) return true;
          const aria = String(btn.getAttribute('aria-label') || '').toLowerCase();
          return aria.includes('credit') || aria.includes('buy') || aria.includes('add');
        });
        return labeled || buttons[0];
      };
      const findAddMoreButton = () => {
        const buttons = collectButtons();
        return buttons.find(btn => matchesAddMore(labelFor(btn))) || null;
      };
      const findNextButton = () => {
        const dialogNext = findDialogNextButton();
        if (dialogNext) return dialogNext;
        const buttons = collectButtons();
        const labeled = buttons.filter(btn => {
          const label = labelFor(btn).toLowerCase();
          return label === 'next' || label.startsWith('next ');
        });
        const visible = labeled.find(isVisible);
        if (visible) return visible;
        const submit = buttons.find(btn => btn.type && String(btn.type).toLowerCase() === 'submit' && isVisible(btn));
        return submit || labeled[0] || null;
      };
      const isDisabled = (el) => {
        if (!el) return true;
        if (el.disabled) return true;
        const ariaDisabled = String(el.getAttribute('aria-disabled') || '').toLowerCase();
        if (ariaDisabled === 'true') return true;
        if (el.classList && (el.classList.contains('disabled') || el.classList.contains('is-disabled'))) {
          return true;
        }
        return false;
      };
      const forceClickElement = (el) => {
        if (!el) return false;
        const rect = el.getBoundingClientRect ? el.getBoundingClientRect() : null;
        if (rect) {
          const x = rect.left + rect.width / 2;
          const y = rect.top + rect.height / 2;
          const target = document.elementFromPoint(x, y);
          if (target) {
            try {
              target.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
              return true;
            } catch {
              return false;
            }
          }
        }
        return false;
      };
      const requestSubmit = (el) => {
        if (!el || !el.closest) return false;
        const form = el.closest('form');
        if (!form) return false;
        if (typeof form.requestSubmit === 'function') {
          form.requestSubmit(el);
          return true;
        }
        if (typeof form.submit === 'function') {
          form.submit();
          return true;
        }
        return false;
      };
      const clickNextIfReady = (attempts) => {
        const nextButton = findNextButton();
        if (!nextButton) {
          if (attempts && attempts % 5 === 0) log('next_missing', { attempts });
          return false;
        }
        if (isDisabled(nextButton)) {
          if (attempts && attempts % 5 === 0) log('next_disabled', summarize(nextButton));
          return false;
        }
        if (!isVisible(nextButton)) {
          if (attempts && attempts % 5 === 0) log('next_hidden', summarize(nextButton));
          return false;
        }
        nextButton.focus?.();
        if (requestSubmit(nextButton)) {
          log('next_submit', summarize(nextButton));
          return true;
        }
        if (triggerPointerClick(nextButton)) {
          log('next_pointer', summarize(nextButton));
          return true;
        }
        if (clickButton(nextButton)) {
          log('next_click', summarize(nextButton));
          return true;
        }
        return forceClickElement(nextButton);
      };
      const startNextPolling = (initialDelay = 500, interval = 500, maxAttempts = 90) => {
        if (window.__runicNextPolling) return;
        window.__runicNextPolling = true;
        log('start_next_poll', { initialDelay, interval, maxAttempts });
        setTimeout(() => {
          let attempts = 0;
          const nextTimer = setInterval(() => {
            attempts += 1;
            if (attempts % 5 === 0) {
              const nextButton = findNextButton();
              log('next_poll', {
                attempts,
                found: Boolean(nextButton),
                summary: summarize(nextButton)
              });
            }
            if (clickNextIfReady(attempts) || attempts >= maxAttempts) {
              clearInterval(nextTimer);
            }
          }, interval);
        }, initialDelay);
      };
      const observeNextButton = () => {
        if (window.__runicNextObserver || !window.MutationObserver) return;
        const observer = new MutationObserver(() => {
          if (clickNextIfReady(1)) {
            observer.disconnect();
            window.__runicNextObserver = null;
          }
        });
        observer.observe(document.body, { subtree: true, childList: true, attributes: true });
        window.__runicNextObserver = observer;
      };
      const findCreditsCardButton = () => {
        const nodes = Array.from(document.querySelectorAll('h1,h2,h3,div,span,p'));
        const labelMatch = nodes.find(node => {
          const lower = textOf(node).toLowerCase();
          return lower === 'credits remaining' || (lower.includes('credits') && lower.includes('remaining'));
        });
        if (!labelMatch) return null;
        let cur = labelMatch;
        for (let i = 0; i < 6 && cur; i++) {
          const buttons = Array.from(cur.querySelectorAll(buttonSelector));
          const picked = pickLikelyButton(buttons);
          if (picked) return picked;
          cur = cur.parentElement;
        }
        return null;
      };
      const findAndClick = () => {
        const addMoreButton = findAddMoreButton();
        if (addMoreButton) {
          log('add_more_click', summarize(addMoreButton));
          clickButton(addMoreButton);
          return true;
        }
        const cardButton = findCreditsCardButton();
        if (!cardButton) return false;
        log('credits_card_click', summarize(cardButton));
        return clickButton(cardButton);
      };
      const logDialogButtons = () => {
        const dialog = document.querySelector('[role=\"dialog\"], dialog, [aria-modal=\"true\"]');
        if (dialog) {
          const buttons = Array.from(dialog.querySelectorAll(buttonSelector)).map(summarize).filter(Boolean);
          if (buttons.length) {
            log('dialog_buttons', { count: buttons.length, buttons: buttons.slice(0, 6) });
          }
          const nextButton = findDialogNextButton();
          if (nextButton) {
            log('dialog_next', summarize(nextButton));
            setTimeout(() => clickNextIfReady(1), 100);
          }
          return;
        }
        const candidates = collectButtons()
          .map(summarize)
          .filter(Boolean)
          .filter(entry => {
            const label = (entry.label || '').toLowerCase();
            return label.includes('next')
              || label.includes('continue')
              || label.includes('confirm')
              || label.includes('buy');
          });
        if (candidates.length) {
          log('button_candidates', { count: candidates.length, buttons: candidates.slice(0, 8) });
        }
      };
      log('auto_start', { href: location.href, ready: document.readyState });
      const iframeSources = Array.from(document.querySelectorAll('iframe'))
        .map(frame => frame.getAttribute('src') || '')
        .filter(Boolean)
        .slice(0, 6);
      if (iframeSources.length) {
        log('iframes', iframeSources);
      }
      const shadowHostCount = Array.from(document.querySelectorAll('*')).filter(el => el.shadowRoot).length;
      if (shadowHostCount > 0) {
        log('shadow_roots', { count: shadowHostCount });
      }
      if (findAndClick()) {
        window.__runicAutoBuyCreditsStarted = true;
        startNextPolling();
        observeNextButton();
        logDialogButtons();
        return 'clicked';
      }
      startNextPolling(500);
      observeNextButton();
      logDialogButtons();
      let attempts = 0;
      const maxAttempts = 14;
      const timer = setInterval(() => {
        attempts += 1;
        if (findAndClick()) {
          logDialogButtons();
          startNextPolling();
          clearInterval(timer);
          return;
        }
        if (attempts >= maxAttempts) {
          clearInterval(timer);
        }
      }, 500);
      window.__runicAutoBuyCreditsStarted = true;
      return 'scheduled';
    })();
    """
}
