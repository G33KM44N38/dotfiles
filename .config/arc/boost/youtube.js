// ==UserScript==
// @name         YouTube Navigation Shortcuts for Arc
// @version      0.7
// @description  Add useful keyboard shortcuts for navigating YouTube in Arc browser with mini-player support, channel navigation, and save to Watch Later feature
// @match        https://www.youtube.com/*
// @grant        none
// ==/UserScript==

(function () {
  "use strict";

  let lastKeyPress = "";
  let timer;

  function toggleMiniPlayer() {
    // if this id is present, then the mini player is closed subscribe-button
    const subscribeButton = document.getElementById("subscribe-button");
    if (subscribeButton) {
      pressKeyI();
    }
  }

  function pressKeyI() {
    const event = new KeyboardEvent("keydown", {
      key: "i",
      keyCode: 73, // ASCII code for 'i'
      which: 73, // ASCII code for 'i'
      bubbles: true,
      cancelable: true,
    });
    document.dispatchEvent(event);
  }

  function openLeftSidebar() {
    const element = document.getElementById("guide-icon");
    element.click();
  }

  function navigateTo(href) {
    const els = document.querySelectorAll(`a[href='${href}']`);
    if (els.length > 0) {
      els[0].click();
    }
  }

  function navigateToMyPlaylist() {
    navigateTo("/feed/playlists");
  }

  function navigateToHistory() {
    navigateTo("/feed/history");
  }

  function navigateToMySubscriptions() {
    navigateTo("/feed/subscriptions");
  }

  function navigateToHome() {
    const element = document.getElementById("logo-icon");
    element.click();
  }

  document.addEventListener("keydown", function (e) {
    // Ignore keypress if user is typing in an input field
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") {
      return;
    }

    clearTimeout(timer);

    const keyMappings = {
      gp: () => {
        navigateToMyPlaylist();
      },
      gh: () => {
        navigateToHistory();
      },
      gs: () => {
        navigateToMySubscriptions();
      },
      ga: () => {
        navigateToHome();
      },
    };

    if (e.key === "g") {
      lastKeyPress = "g";
    } else if (lastKeyPress === "g") {
      const action = keyMappings[`g${e.key}`];
      if (action) {
        toggleMiniPlayer();
        openLeftSidebar();
        action();
        openLeftSidebar();
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
