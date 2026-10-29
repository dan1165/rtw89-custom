/* SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause */
/* Shims for kernels older than the tree this driver was taken from (v7.0-rc1).
 * Forced in with -include from the Kbuild, so no source file needs to know.
 *
 * Two boundaries matter: 6.18 (mac80211/cfg80211/debugfs API changes) and 7.0
 * (typed allocators). Below 6.5 the link API itself is missing and this tree
 * cannot be used at all.
 */
#ifndef __RTW89_COMPAT_H__
#define __RTW89_COMPAT_H__

#include <linux/version.h>
#include <linux/slab.h>

/* typed allocators with an optional gfp argument, 7.0 */
#if LINUX_VERSION_CODE < KERNEL_VERSION(7, 0, 0)
#define __rtw89_gfp_pick(_a, ...) _a
#define __rtw89_gfp(...) __rtw89_gfp_pick(__VA_ARGS__ __VA_OPT__(, ) GFP_KERNEL, GFP_KERNEL)

#define kmalloc_obj(_obj, ...) kmalloc(sizeof(_obj), __rtw89_gfp(__VA_ARGS__))
#define kzalloc_obj(_obj, ...) kzalloc(sizeof(_obj), __rtw89_gfp(__VA_ARGS__))
#define kzalloc_objs(_obj, _n, ...) kcalloc(_n, sizeof(_obj), __rtw89_gfp(__VA_ARGS__))
#define kzalloc_flex(_obj, _fam, _n, ...) \
	kzalloc(struct_size(&(_obj), _fam, _n), __rtw89_gfp(__VA_ARGS__))
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 17, 0)
/* WQ_PERCPU, 6.17: per-cpu was the default before */
#define WQ_PERCPU 0

/* debugfs_short_fops, 6.17: a trimmed file_operations for debugfs */
#define debugfs_short_fops file_operations
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 18, 0)
/* cfg80211_bitrate_mask gained an EHT MCS/LTF/GI mask in 6.18; the HE one is
 * the closest thing before that (same NSS range, MCS 0-11).
 */
#define rtw89_mask_eht_mcs(_mask, _band) ((_mask)->control[_band].he_mcs)
#define rtw89_mask_eht_ltf(_mask, _band) ((_mask)->control[_band].he_ltf)
#define rtw89_mask_eht_gi(_mask, _band) ((_mask)->control[_band].he_gi)
#else
#define rtw89_mask_eht_mcs(_mask, _band) ((_mask)->control[_band].eht_mcs)
#define rtw89_mask_eht_ltf(_mask, _band) ((_mask)->control[_band].eht_ltf)
#define rtw89_mask_eht_gi(_mask, _band) ((_mask)->control[_band].eht_gi)
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 18, 0)

/* wiphy_locked_debugfs_{read,write}, 6.18. The upstream versions bounce the
 * handler through wiphy_work; a plain wiphy_lock() is enough for debugfs.
 */
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <net/cfg80211.h>

static inline ssize_t
rtw89_compat_locked_read(struct wiphy *wiphy, struct file *file, char *buf,
			 size_t bufsize, char __user *userbuf, size_t count,
			 loff_t *ppos,
			 ssize_t (*handler)(struct wiphy *, struct file *,
					    char *, size_t, void *),
			 void *data)
{
	ssize_t ret;

	memset(buf, 0, bufsize);
	wiphy_lock(wiphy);
	ret = handler(wiphy, file, buf, bufsize, data);
	wiphy_unlock(wiphy);
	if (ret < 0)
		return ret;

	return simple_read_from_buffer(userbuf, count, ppos, buf, ret);
}

static inline ssize_t
rtw89_compat_locked_write(struct wiphy *wiphy, struct file *file, char *buf,
			  size_t bufsize, const char __user *userbuf,
			  size_t count,
			  ssize_t (*handler)(struct wiphy *, struct file *,
					     char *, size_t, void *),
			  void *data)
{
	ssize_t ret;

	if (count > bufsize - 1)
		return -EINVAL;
	if (copy_from_user(buf, userbuf, count))
		return -EFAULT;
	buf[count] = '\0';

	wiphy_lock(wiphy);
	ret = handler(wiphy, file, buf, count, data);
	wiphy_unlock(wiphy);

	return ret;
}

#define wiphy_locked_debugfs_read rtw89_compat_locked_read
#define wiphy_locked_debugfs_write rtw89_compat_locked_write
#endif

/* The next few are enum members or functions in newer kernels, so they need a
 * version guard rather than #ifndef.
 */
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 7, 0)
#define umin(_a, _b) min_t(u32, _a, _b)

#define IEEE80211_RADIOTAP_EHT_USIG_COMMON_BW_20MHZ 0
#define IEEE80211_RADIOTAP_EHT_USIG_COMMON_BW_40MHZ 1
#define IEEE80211_RADIOTAP_EHT_USIG_COMMON_BW_80MHZ 2
#define IEEE80211_RADIOTAP_EHT_USIG_COMMON_BW_160MHZ 3
#define IEEE80211_RADIOTAP_EHT_USIG_COMMON_BW_320MHZ_1 4
#define IEEE80211_RADIOTAP_EHT_USIG_COMMON_BW_320MHZ_2 5

#include <linux/netdevice.h>
#define napi_is_scheduled(_n) test_bit(NAPI_STATE_SCHED, &(_n)->state)
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 9, 0)
#include <linux/netdevice.h>
static inline struct net_device *rtw89_compat_alloc_netdev_dummy(int sizeof_priv)
{
	return alloc_netdev(sizeof_priv, "dummy%d", NET_NAME_ENUM, NULL);
}
#define alloc_netdev_dummy rtw89_compat_alloc_netdev_dummy
#endif

#endif
