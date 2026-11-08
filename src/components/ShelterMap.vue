<script setup lang="ts">
import { onMounted, onUnmounted, ref, watch } from "vue";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

const props = withDefaults(
  defineProps<{
    latitude: number | null;
    longitude: number | null;
    interactive?: boolean;
  }>(),
  { interactive: false },
);
const emit = defineEmits<{
  select: [coordinates: { latitude: number; longitude: number }];
}>();

const mapElement = ref<HTMLDivElement | null>(null);
let map: L.Map | null = null;
let marker: L.Marker | null = null;
let resizeObserver: ResizeObserver | null = null;
let resizeFrame = 0;

const hasCoordinates = () =>
  props.latitude !== null &&
  props.longitude !== null &&
  Number.isFinite(props.latitude) &&
  Number.isFinite(props.longitude);

const setMarker = (latitude: number, longitude: number) => {
  const coordinates: L.LatLngExpression = [latitude, longitude];
  if (marker) {
    marker.setLatLng(coordinates);
  } else if (map) {
    marker = L.marker(coordinates, {
      icon: L.divIcon({
        className: "",
        html: '<svg xmlns="http://www.w3.org/2000/svg" width="44" height="56" viewBox="0 0 44 56" aria-label="Shelter pin"><path d="M22 1C10.4 1 1 10.4 1 22c0 15.5 21 33 21 33s21-17.5 21-33C43 10.4 33.6 1 22 1Z" fill="#c62828" stroke="#fff" stroke-width="3"/><circle cx="22" cy="22" r="7" fill="#fff"/></svg>',
        iconSize: [44, 56],
        iconAnchor: [22, 56],
      }),
      title: "Shelter location",
      keyboard: false,
      zIndexOffset: 1000,
      riseOnHover: true,
    }).addTo(map);
    marker.bindPopup("Shelter location");
  }
};

onMounted(() => {
  if (!mapElement.value) return;

  map = L.map(mapElement.value, {
    center: hasCoordinates()
      ? [props.latitude!, props.longitude!]
      : [14.5995, 120.9842],
    zoom: hasCoordinates() ? 15 : 6,
    dragging: props.interactive,
    touchZoom: props.interactive,
    doubleClickZoom: props.interactive,
    boxZoom: props.interactive,
    keyboard: props.interactive,
    zoomControl: props.interactive,
    scrollWheelZoom: false,
  });
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19,
  }).addTo(map);

  if (hasCoordinates()) setMarker(props.latitude!, props.longitude!);
  if (props.interactive) {
    map.on("click", (event: L.LeafletMouseEvent) => {
      setMarker(event.latlng.lat, event.latlng.lng);
      emit("select", {
        latitude: event.latlng.lat,
        longitude: event.latlng.lng,
      });
    });
  }

  resizeObserver = new ResizeObserver(() => {
    cancelAnimationFrame(resizeFrame);
    resizeFrame = requestAnimationFrame(() => map?.invalidateSize({ pan: false }));
  });
  resizeObserver.observe(mapElement.value);
  resizeFrame = requestAnimationFrame(() => map?.invalidateSize({ pan: false }));
});

watch(
  () => [props.latitude, props.longitude] as const,
  ([latitude, longitude]) => {
    if (!map || latitude === null || longitude === null) return;
    setMarker(latitude, longitude);
    map.setView([latitude, longitude], Math.max(map.getZoom(), 15));
  },
);

onUnmounted(() => {
  resizeObserver?.disconnect();
  cancelAnimationFrame(resizeFrame);
  map?.remove();
  map = null;
  marker = null;
});
</script>

<template>
  <div
    ref="mapElement"
    class="shelter-map"
    :class="{ 'shelter-map--interactive': interactive }"
    :aria-label="interactive ? 'Click the map to pin the shelter location' : 'Map showing the shelter location'"
    role="application"
  />
</template>

<style scoped>
.shelter-map {
  width: 100%;
  min-height: 300px;
  border-radius: 16px;
  background: #e8eee6;
  z-index: 0;
}

.shelter-map--interactive {
  cursor: crosshair;
}
</style>
