/**
 * Abyss Spotlight — injects the home hero iframe when Jellyfin's stock home-html chunk has no banner.
 * Loaded from index.html so it survives Jellyfin web bundle updates that reset home-html.*.chunk.js.
 */
(function () {
    'use strict';

    if (window.AbyssSpotlightInject) return;
    window.AbyssSpotlightInject = { version: '1.0.0' };

    const IFRAME_SRC = '/web/ui/spotlight.html';
    const STYLE_ID = 'abyss-spotlight-inject-styles';

    const SPOTLIGHT_CSS = `
#homeTab .featurediframe {
    width: 100%;
    display: block;
    border: 0;
    margin: 0;
    padding: 0;
    height: 70vh;
    min-height: 420px;
    max-height: 680px;
}
@media (min-width: 1400px) {
    #homeTab .featurediframe { height: 72vh; max-height: 760px; }
}
@media (min-width: 1920px) {
    #homeTab .featurediframe { height: 68vh; max-height: 860px; }
}
@media (max-width: 1024px) and (orientation: portrait) {
    #homeTab .featurediframe { height: 90vh; min-height: 320px; max-height: 720px; }
}
@media (max-width: 1024px) and (orientation: landscape) {
    #homeTab .featurediframe { height: 100vh; min-height: 280px; max-height: 420px; }
}
@media (max-width: 600px) and (orientation: portrait) {
    #homeTab .featurediframe { height: 90vh; min-height: 260px; max-height: 720px; }
}
#indexPage #homeTab.is-active .featurediframe {
    display: block !important;
    visibility: visible !important;
}
#indexPage #homeTab:not(.is-active) .featurediframe {
    display: none !important;
}
`;

    function ensureStyles() {
        if (document.getElementById(STYLE_ID)) return;
        const el = document.createElement('style');
        el.id = STYLE_ID;
        el.textContent = SPOTLIGHT_CSS;
        document.head.appendChild(el);
    }

    function syncVisibility(homeTab, iframe) {
        const active = homeTab.classList.contains('is-active');
        iframe.style.display = active ? 'block' : 'none';
        iframe.hidden = !active;
    }

    function wireTab(homeTab, iframe) {
        syncVisibility(homeTab, iframe);
        if (iframe.dataset.abyssSpotlightWired === '1') return;
        iframe.dataset.abyssSpotlightWired = '1';
        new MutationObserver(() => syncVisibility(homeTab, iframe)).observe(homeTab, {
            attributes: true,
            attributeFilter: ['class']
        });
    }

    function injectSpotlight() {
        const homeTab = document.getElementById('homeTab');
        if (!homeTab) return false;

        let iframe = homeTab.querySelector('.featurediframe');
        if (!iframe) {
            const sections = homeTab.querySelector('.sections');
            iframe = document.createElement('iframe');
            iframe.className = 'featurediframe';
            iframe.src = IFRAME_SRC;
            iframe.title = 'Abyss Spotlight';
            iframe.setAttribute('loading', 'lazy');
            iframe.setAttribute('allow', 'autoplay; fullscreen');

            if (sections) {
                homeTab.insertBefore(iframe, sections);
            } else {
                homeTab.prepend(iframe);
            }
        } else if (!iframe.src || iframe.src === 'about:blank') {
            iframe.src = IFRAME_SRC;
        }

        wireTab(homeTab, iframe);
        return true;
    }

    function boot() {
        ensureStyles();
        injectSpotlight();
    }

    let debounce = null;
    function scheduleBoot() {
        if (debounce) clearTimeout(debounce);
        debounce = setTimeout(boot, 50);
    }

    function start() {
        boot();
        new MutationObserver(scheduleBoot).observe(document.body, {
            childList: true,
            subtree: true
        });
        window.addEventListener('hashchange', scheduleBoot);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
    } else {
        start();
    }
})();
