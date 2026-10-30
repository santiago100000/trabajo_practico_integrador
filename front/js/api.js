const api = {
    async getSalud() {
        const res = await fetch(`${API_BASE_URL}/salud`);
        if (!res.ok) {
            throw new Error(`HTTP ${res.status}`);
        }
        return await res.json();
    },
};

export default api;
