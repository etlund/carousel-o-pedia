module MountsHelper
  MOUNT_ICON_PATHS = {
    "jumper" => "M8 2v12 M4.5 5.5 8 2l3.5 3.5 M4.5 10.5 8 14l3.5-3.5",
    "stander" => "M3 8h10",
    "spinning" => "M13 6a5.2 5.2 0 1 0 .2 3 M9 6h4V2",
    "fixed" => "M4 4h8v8H4Z"
  }.freeze

  def mount_icon(mount, decorative: false, size: 16, x: nil, y: nil)
    return if mount.blank?

    path = MOUNT_ICON_PATHS.fetch(mount)
    tag.svg(class: "mount-icon", viewBox: "0 0 16 16", width: size, height: size, x:, y:,
            fill: "none", stroke: "currentColor", "stroke-width": 1.8,
            "stroke-linecap": "round", "stroke-linejoin": "round", focusable: "false",
            role: ("img" unless decorative), "aria-label": (mount.capitalize unless decorative),
            "aria-hidden": (true if decorative)) do
      safe_join([
        (tag.title(mount.capitalize) unless decorative),
        tag.path(d: path, fill: (mount == "fixed" ? "currentColor" : "none"))
      ])
    end
  end
end
