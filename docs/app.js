/* Pastable site — small progressive enhancements only. */
(() => {
  "use strict";

  const header = document.querySelector(".site-header");
  const showcase = document.querySelector(".showcase");
  if (header) {
    const onScroll = () => {
      header.classList.toggle("is-scrolled", window.scrollY > 8);
      if (showcase) {
        const edge = header.offsetHeight;
        const rect = showcase.getBoundingClientRect();
        // Stay light until the dark section is genuinely behind the header,
        // and revert before its bottom edge turns the header into a dark bar.
        header.classList.toggle(
          "on-dark",
          rect.top <= edge - 8 && rect.bottom >= edge + 24
        );
      }
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
  }

  // Light / dark panel preview on the showcase.
  const switcher = document.querySelector("[data-theme-switch]");
  const preview = document.querySelector("[data-theme-preview]");
  if (switcher && preview) {
    const buttons = Array.from(switcher.querySelectorAll("[data-theme]"));
    const images = {
      dark: { src: preview.dataset.darkSrc, alt: preview.dataset.darkAlt },
      light: { src: preview.dataset.lightSrc, alt: preview.dataset.lightAlt },
    };

    // Warm the cache so the crossfade never shows a blank frame.
    Object.values(images).forEach((item) => {
      if (item.src) {
        const img = new Image();
        img.src = item.src;
      }
    });

    buttons.forEach((button) => {
      button.addEventListener("click", () => {
        const theme = button.dataset.theme;
        const next = images[theme];
        if (!next || button.getAttribute("aria-selected") === "true") return;

        buttons.forEach((item) => item.setAttribute("aria-selected", String(item === button)));

        preview.classList.add("is-switching");
        const swap = () => {
          preview.src = next.src;
          preview.alt = next.alt;
          preview.classList.remove("is-switching");
        };
        window.setTimeout(swap, 160);
      });
    });
  }

  // Gentle reveal on scroll, skipped for reduced motion.
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const revealables = document.querySelectorAll(".reveal");
  if (!reduceMotion && "IntersectionObserver" in window) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { rootMargin: "0px 0px -12% 0px", threshold: 0.08 }
    );
    revealables.forEach((element) => observer.observe(element));
  } else {
    revealables.forEach((element) => element.classList.add("is-visible"));
  }

  // Mark the current year in the footer without hardcoding it repeatedly.
  document.querySelectorAll("[data-year]").forEach((element) => {
    element.textContent = String(new Date().getFullYear());
  });
})();
