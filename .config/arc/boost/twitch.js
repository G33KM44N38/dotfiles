// ==UserScript==
// @name         Twitch Navigation Shortcuts for Arc
// @version      0.7
// @description  Add useful keyboard shortcuts for navigating Twitch in Arc browser with following and browse directory navigation
// @match        https://www.twitch.tv/*
// @grant        none
// ==/UserScript==

(function () {
  "use strict";

  let lastKeyPress = "";
  let timer;

  function navigateTo(href) {
    const els = document.querySelectorAll(`a[href='${href}']`);
    if (els.length > 0) {
      els[0].click();
    } else {
      // If no element found, navigate directly using window.location
      window.location.href = `https://www.twitch.tv${href}`;
    }
  }

  function navigateToFollowing() {
    navigateTo("/directory/following");
  }

  function navigateToBrowse() {
    navigateTo("/directory");
  }

  function navigateToHome() {
    const homeButton = document.querySelector('[data-a-target="home-link"]');
    if (homeButton) {
      homeButton.click();
    } else {
      window.location.href = "https://www.twitch.tv";
    }
  }

  function newSearch() {
    const searchInput = document.querySelector(
      '[data-a-target="search-input"]',
    );
    if (searchInput) {
      searchInput.click();
    } else {
      window.location.href = "https://www.twitch.tv/search";
    }
  }

  document.addEventListener("keydown", function (e) {
    // Ignore keypress if user is typing in an input field
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") {
      return;
    }

    clearTimeout(timer);

    const keyMappings = {
      gf: () => {
        navigateToFollowing();
      },
      gb: () => {
        navigateToBrowse();
      },
      gh: () => {
        navigateToHome();
      },
      gs: () => {
        newSearch();
      },
    };

    if (e.key === "g") {
      lastKeyPress = "g";
    } else if (lastKeyPress === "g") {
      const action = keyMappings[`g${e.key}`];
      if (action) {
        action();
        lastKeyPress = "";
      } else {
        lastKeyPress = "";
      }
    } else {
      lastKeyPress = "";
    }

    timer = setTimeout(() => {
      lastKeyPress = "";
    }, 1000); // 1 second window to complete the shortcut
  });
})();
