// Function to convert HEX to HSL
function hexToHSL(hex) {
  let r = parseInt(hex.slice(1, 3), 16) / 255;
  let g = parseInt(hex.slice(3, 5), 16) / 255;
  let b = parseInt(hex.slice(5, 7), 16) / 255;

  let max = Math.max(r, g, b);
  let min = Math.min(r, g, b);
  let h, s, l = (max + min) / 2;

  if (max === min) {
    h = s = 0; // achromatic
  } else {
    let d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
    }
    h /= 6;
  }

  return { h: h * 360, s: s * 100, l: l * 100 };
}

// Function to convert HSL to HEX
function hslToHex(h, s, l) {
  h /= 360;
  s /= 100;
  l /= 100;

  let r, g, b;

  if (s === 0) {
    r = g = b = l; // achromatic
  } else {
    let hue2rgb = function (p, q, t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 3) return q;
      if (t < 1 / 2) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    };

    let q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    let p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }

  return `#${Math.round(r * 255).toString(16).padStart(2, '0')}${Math.round(g * 255).toString(16).padStart(2, '0')}${Math.round(b * 255).toString(16).padStart(2, '0')}`;
}

// Function to adjust the brightness of the color
function adjustBrightness(hex, factor) {
  let hsl = hexToHSL(hex);
  hsl.l = Math.min(100, Math.max(0, hsl.l * factor)); // adjust luminance
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// DOMContentLoaded event to ensure the DOM is fully loaded before running the script
document.addEventListener("DOMContentLoaded", function() {
  const cards = document.getElementsByClassName('card-personalizado');
  var arr = Array.prototype.slice.call( cards )
  arr.map((card) => {
    const cardColor = window.getComputedStyle(card).backgroundColor;
  
    // Convert the rgb color to hex
    function rgbToHex(rgb) {
      const rgbArray = rgb.match(/\d+/g);
      return `#${rgbArray.map(x => {
        const hex = parseInt(x).toString(16);
        return hex.length === 1 ? '0' + hex : hex;
      }).join('')}`;
    }
  
    const cardColorHex = rgbToHex(cardColor);
    const borderColor = adjustBrightness(cardColorHex, 0.8); // 20% darker
    card.style.borderColor = borderColor;
  })
});