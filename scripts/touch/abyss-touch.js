/**
 * Abyss Touch — double-tap screen edges to rewind / fast-forward in Jellyfin video playback.
 * Defers to Jellyfin's native seek buttons; does not attach outside the video player page.
 */
(function () {
    'use strict';

    if (window.AbyssTouch) return;
    window.AbyssTouch = { version: '1.0.1' };

    const DOUBLE_TAP_MS = 320;
    const SIDE_FRACTION = 0.38;
    const FEEDBACK_MS = 750;
    const PAGE_ID = 'videoOsdPage';

    const IGNORE_SELECTOR = [
        '.videoOsdBottom',
        '.osdControls',
        '.osdHeader',
        '.dialog',
        '.upNextContainer',
        '.mainDrawer',
        '.syncPlayContainer',
        '.playerStats',
        '.subtitleSyncOverlay',
        '#abyss-seek-feedback'
    ].join(', ');

    let lastTap = { side: null, time: 0 };
    let feedbackEl = null;
    let bound = false;
    let pageObserver = null;

    function isTouchContext() {
        if (document.body.classList.contains('layout-mobile')) return true;
        try {
            return window.matchMedia('(hover: none) and (pointer: coarse)').matches;
        } catch {
            return false;
        }
    }

    function isVideoActive() {
        const page = document.getElementById(PAGE_ID);
        return !!(page && page.classList.contains('page') && !page.classList.contains('hide'));
    }

    function getSkipSeconds(direction) {
        const needle = direction === 'back' ? 'skipBackLength' : 'skipForwardLength';
        const fallback = direction === 'back' ? 10 : 30;

        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (!key || !key.includes(needle)) continue;
            const raw = parseInt(localStorage.getItem(key), 10);
            if (!Number.isNaN(raw) && raw > 0) return Math.round(raw / 1000);
        }

        return fallback;
    }

    function performSeek(side) {
        const selector = side === 'left'
            ? `#${PAGE_ID} .btnRewind`
            : `#${PAGE_ID} .btnFastForward`;
        const btn = document.querySelector(selector);

        if (!btn || btn.disabled || btn.classList.contains('hide')) {
            return false;
        }

        btn.click();
        showSeekFeedback(side);
        return true;
    }

    function showSeekFeedback(side) {
        if (!feedbackEl) {
            feedbackEl = document.createElement('div');
            feedbackEl.id = 'abyss-seek-feedback';
            feedbackEl.setAttribute('aria-hidden', 'true');
            document.body.appendChild(feedbackEl);
        }

        const seconds = side === 'left' ? getSkipSeconds('back') : getSkipSeconds('forward');
        const label = side === 'left' ? `-${seconds}` : `+${seconds}`;
        const chevrons = side === 'left' ? '«' : '»';

        feedbackEl.className = '';
        feedbackEl.classList.add('abyss-seek-feedback', side === 'left' ? 'is-rewind' : 'is-forward');
        feedbackEl.innerHTML = `
            <span class="abyss-seek-feedback__chevrons">${chevrons}</span>
            <span class="abyss-seek-feedback__label">${label} sec</span>
        `;

        requestAnimationFrame(() => {
            feedbackEl.classList.add('is-visible');
        });

        clearTimeout(showSeekFeedback._timer);
        showSeekFeedback._timer = setTimeout(() => {
            feedbackEl.classList.remove('is-visible');
        }, FEEDBACK_MS);
    }

    function tapSide(clientX) {
        const width = window.innerWidth;
        if (clientX < width * SIDE_FRACTION) return 'left';
        if (clientX > width * (1 - SIDE_FRACTION)) return 'right';
        return null;
    }

    function shouldIgnoreTarget(target) {
        return !!(target && target.closest && target.closest(IGNORE_SELECTOR));
    }

    function onTouchEnd(event) {
        if (!bound || !isVideoActive()) return;
        if (event.changedTouches.length !== 1) return;

        const touch = event.changedTouches[0];
        if (!touch) return;

        const side = tapSide(touch.clientX);
        if (!side) return;

        if (shouldIgnoreTarget(event.target)) return;

        const now = Date.now();
        if (lastTap.side === side && now - lastTap.time <= DOUBLE_TAP_MS) {
            if (performSeek(side)) {
                event.preventDefault();
                event.stopImmediatePropagation();
            }
            lastTap = { side: null, time: 0 };
            return;
        }

        lastTap = { side, time: now };
    }

    function bind() {
        if (bound || !isTouchContext()) return;
        document.addEventListener('touchend', onTouchEnd, { capture: true, passive: false });
        document.body.classList.add('abyss-touch-enabled');
        bound = true;
    }

    function unbind() {
        if (!bound) return;
        document.removeEventListener('touchend', onTouchEnd, { capture: true });
        document.body.classList.remove('abyss-touch-enabled');
        bound = false;
        lastTap = { side: null, time: 0 };
    }

    function syncBinding() {
        if (isTouchContext() && isVideoActive()) {
            bind();
        } else {
            unbind();
        }
    }

    function watchVideoPage() {
        const page = document.getElementById(PAGE_ID);
        if (!page) {
            unbind();
            return;
        }

        if (pageObserver) {
            pageObserver.disconnect();
            pageObserver = null;
        }

        pageObserver = new MutationObserver(syncBinding);
        pageObserver.observe(page, { attributes: true, attributeFilter: ['class', 'style'] });
        syncBinding();
    }

    function init() {
        if (!isTouchContext()) return;

        watchVideoPage();

        const root = document.getElementById('reactRoot') || document.body;
        const rootObserver = new MutationObserver(() => {
            if (document.getElementById(PAGE_ID)) {
                watchVideoPage();
            } else {
                unbind();
                if (pageObserver) {
                    pageObserver.disconnect();
                    pageObserver = null;
                }
            }
        });
        rootObserver.observe(root, { childList: true, subtree: true });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init, { once: true });
    } else {
        init();
    }
})();
