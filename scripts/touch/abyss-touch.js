/**
 * Abyss Touch — double-tap screen edges to rewind / fast-forward in Jellyfin video playback.
 */
(function () {
    'use strict';

    if (window.AbyssTouch) return;
    window.AbyssTouch = { version: '1.0.0' };

    const DOUBLE_TAP_MS = 320;
    const SIDE_FRACTION = 0.38;
    const FEEDBACK_MS = 750;
    const PAGE_ID = 'videoOsdPage';

    let lastTap = { side: null, time: 0 };
    let feedbackEl = null;
    let bound = false;

    function isTouchContext() {
        return document.body.classList.contains('layout-mobile')
            || window.matchMedia('(pointer: coarse)').matches
            || navigator.maxTouchPoints > 0;
    }

    function isVideoActive() {
        const page = document.getElementById(PAGE_ID);
        return page && page.classList.contains('page') && !page.classList.contains('hide');
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

        if (btn && !btn.disabled) {
            btn.click();
            showSeekFeedback(side);
            return true;
        }

        const video = document.querySelector(`#${PAGE_ID} video`) || document.querySelector('video');
        if (!video || Number.isNaN(video.currentTime)) return false;

        const delta = side === 'left' ? -getSkipSeconds('back') : getSkipSeconds('forward');
        const duration = Number.isFinite(video.duration) ? video.duration : null;
        let next = video.currentTime + delta;
        if (duration != null) next = Math.max(0, Math.min(duration, next));
        else next = Math.max(0, next);

        video.currentTime = next;
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

    function onTouchEnd(event) {
        if (!isTouchContext() || !isVideoActive()) return;
        if (event.touches.length > 0) return;

        const touch = event.changedTouches[0];
        if (!touch) return;

        const side = tapSide(touch.clientX);
        if (!side) return;

        const target = event.target;
        if (target && target.closest('.videoOsdBottom, .osdControls, .dialog, .upNextContainer, .mainDrawer')) {
            return;
        }

        const now = Date.now();
        if (lastTap.side === side && now - lastTap.time <= DOUBLE_TAP_MS) {
            event.preventDefault();
            event.stopPropagation();
            performSeek(side);
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
    }

    function syncBinding() {
        if (isTouchContext() && isVideoActive()) bind();
        else if (!isVideoActive()) {
            lastTap = { side: null, time: 0 };
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', bind);
    } else {
        bind();
    }

    const observer = new MutationObserver(syncBinding);
    observer.observe(document.documentElement, {
        subtree: true,
        attributes: true,
        attributeFilter: ['class']
    });

    window.addEventListener('resize', syncBinding);
})();
