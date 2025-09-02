module CardsHelper
  def card_style(card)
    styles = {
      "NUBANK" =>      { color: "#8A05BE", rgb: "138, 5, 190",  logo: "nubank-icon-colored.png",      flag: "mastercard.png" },
      "ITAÚ CLICK" =>  { color: "#FF6200", rgb: "255, 98, 0",   logo: "itau-icon-colored.png",        flag: "visa.png" },
      "CASAS BAHIA" => { color: "#007BFF", rgb: "0, 123, 255",  logo: "casas-bahia-icon-colored.png", flag: "visa.png" },
      "DIGIO" =>       { color: "#002F87", rgb: "0, 47, 135",   logo: "digio-icon-colored.png",       flag: "visa.png" },
      "OUTROS" =>      { color: "#0DCAF0", rgb: "13, 202, 240", logo: "creditcard.png",               flag: "" },
      "RENNER" =>      { color: "#000000", rgb: "0, 0, 0",      logo: "renner-icon-colored.png",      flag: "mastercard.png" },
      "WILL" =>        { color: "#FFC107", rgb: "255, 193, 7",  logo: "will-icon-colored.png",        flag: "mastercard.png" },
      "PAN" =>         { color: "#17A2B8", rgb: "23, 162, 184", logo: "pan-icon-colored.png",         flag: "mastercard.png" },
      "ITI" =>         { color: "#E91E63", rgb: "233, 30, 99",  logo: "iti-icon-colored.png",         flag: "visa.png" },
      "RECARGA PAY" => { color: "#07233e", rgb: "7, 35, 62",    logo: "pay-icon-colored.png",         flag: "mastercard.png" }
    }

    styles[card.name.upcase] || { color: "#CED4DA", logo: "creditcard.png", flag: "" }
  end
end
